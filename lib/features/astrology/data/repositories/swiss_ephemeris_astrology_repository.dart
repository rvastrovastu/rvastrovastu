import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'package:timezone/timezone.dart' as tz;
import 'package:swisseph/swisseph.dart';

import '../../domain/entities/kundali.dart';
import '../../domain/entities/planet_position.dart';
import '../../domain/entities/rashi_chart.dart';
import '../../domain/models/kundali_input.dart';
import 'astrology_repository.dart';

class SwissEphemerisAstrologyRepository implements AstrologyRepository {
  static const int _siderealFlags = seFlgSwiEph | seFlgSpeed | seFlgSidereal;

  @override
  Future<Kundali> calculateKundali(KundaliInput input) async {
    final swe = await _loadSwissEph();

    try {
      /*
       * IMPORTANT:
       * Re-set Swiss Ephemeris configuration immediately before calculation.
       *
       * RV Astro Vastu standard:
       * - Sidereal zodiac
       * - Lahiri ayanamsa
       * - Whole-sign Rashi houses
       */

      swe.setSidMode(seSidmLahiri);

      final date = input.dateOfBirth;
      final time = _parseBirthTime(input.birthTime);
      debugPrint('[ASTROLOGY] ============================================');
      debugPrint('[ASTROLOGY] DOB=${input.dateOfBirth}');
      debugPrint('[ASTROLOGY] BIRTH TIME=${input.birthTime}');
      debugPrint('[ASTROLOGY] LAT=${input.latitude}');
      debugPrint('[ASTROLOGY] LNG=${input.longitude}');
      debugPrint('[ASTROLOGY] TIMEZONE=${input.timezone}');
      debugPrint(
        '[ASTROLOGY] PARSED LOCAL='
        '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}',
      );
      final utc = _localToUtc(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
        time.second,
        input.timezone,
      );

      debugPrint('[ASTROLOGY] UTC=$utc');

      final jd = swe.utcToJd(
        utc.year,
        utc.month,
        utc.day,
        utc.hour,
        utc.minute,
        utc.second.toDouble(),
      );

      final jdUt = jd.ut1;
      debugPrint('[ASTROLOGY] JD_UT=$jdUt');
      debugPrint('[ASTROLOGY] AYANAMSA=${swe.getAyanamsaUt(jdUt)}');

      final ayanamsa = swe.getAyanamsaUt(jdUt);

      /*
       * Calculate Ascendant / MC.
       *
       * We calculate the astronomical ascendant using
       * Swiss Ephemeris, then convert it into the sidereal zodiac.
       */
      final houses = swe.housesEx(
        jdUt,
        seFlgSidereal,
        input.latitude,
        input.longitude,
        'P'.codeUnitAt(0),
      );

      final ascendant = _normalize(houses.ascendant);

      final planets = <PlanetPosition>[];

      final planetDefinitions = <_PlanetDefinition>[
        const _PlanetDefinition('Sun', seSun),
        const _PlanetDefinition('Moon', seMoon),
        const _PlanetDefinition('Mars', seMars),
        const _PlanetDefinition('Mercury', seMercury),
        const _PlanetDefinition('Jupiter', seJupiter),
        const _PlanetDefinition('Venus', seVenus),
        const _PlanetDefinition('Saturn', seSaturn),
      ];

      for (final definition in planetDefinitions) {
        final result = swe.calcUt(jdUt, definition.body, _siderealFlags);

        final longitude = _normalize(result.longitude);
        debugPrint(
          '[ASTROLOGY][PLANET] '
          '${definition.name} longitude=${longitude.toStringAsFixed(6)} '
          'speed=${result.longitudeSpeed.toStringAsFixed(6)}',
        );

        planets.add(
          _planetPosition(
            definition.name,
            longitude,
            result.longitudeSpeed,
            ascendant,
          ),
        );
      }

      /*
       * Rahu
       *
       * Vedic charts normally use the mean lunar node.
       * Ketu is exactly 180 degrees opposite Rahu.
       */
      final rahuResult = swe.calcUt(jdUt, seMeanNode, _siderealFlags);

      final rahuLongitude = _normalize(rahuResult.longitude);
      final ketuLongitude = _normalize(rahuLongitude + 180.0);

      planets.add(
        _planetPosition(
          'Rahu',
          rahuLongitude,
          rahuResult.longitudeSpeed,
          ascendant,
        ),
      );

      planets.add(
        _planetPosition(
          'Ketu',
          ketuLongitude,
          -rahuResult.longitudeSpeed,
          ascendant,
        ),
      );

      final sun = planets.firstWhere((p) => p.planet == 'Sun');
      final moon = planets.firstWhere((p) => p.planet == 'Moon');
      debugPrint(
        '[ASTROLOGY][MOON] '
        'longitude=${moon.longitude.toStringAsFixed(6)} '
        'sign=${moon.sign} '
        'degree=${moon.degree.toStringAsFixed(6)} '
        'nakshatra=${moon.nakshatra} '
        'pada=${moon.nakshatraPada}',
      );

      final moonNakshatra = _nakshatra(moon.longitude);
      final moonPada = _nakshatraPada(moon.longitude);

      final rashiHouses = _buildWholeSignChart(ascendant, planets);

      return Kundali(
        ayanamsa: ayanamsa,
        ascendant: _signFromLongitude(ascendant),
        ascendantDegree: _degreeWithinSign(ascendant),
        moonLongitude: moon.longitude,
        moonSign: moon.sign,
        sunSign: sun.sign,
        nakshatra: moonNakshatra,
        nakshatraPada: moonPada,
        planets: planets,
        rashiChart: RashiChart(houses: rashiHouses),
      );
    } finally {
      swe.close();
    }
  }

  /// Loads Swiss Ephemeris from the Flutter native-assets bundle.
  ///
  /// The swisseph package's default loader searches `.dart_tool/`, which
  /// works for Dart development but not for an iOS application bundle.
  /// Flutter bundles the native asset as:
  ///
  ///   Runner.app/Frameworks/swisseph.framework/swisseph
  ///
  /// Resolve the bundled Swiss Ephemeris native library.
  ///
  /// Flutter iOS bundles native frameworks at:
  /// `<Runner.app>`/Frameworks/swisseph.framework/swisseph
  ///
  /// Platform.resolvedExecutable points to:
  /// `<Runner.app>`/Runner
  Future<SwissEph> _loadSwissEph() async {
    if (Platform.isIOS) {
      final executable = File(Platform.resolvedExecutable);

      // iOS:
      // <Runner.app>/Runner
      // <Runner.app>/Frameworks/swisseph.framework/swisseph
      final appDirectory = executable.parent;

      final bundledFramework =
          '${appDirectory.path}/Frameworks/swisseph.framework/swisseph';

      developer.log('[SWISSEPH][IOS] executable=${executable.path}');
      developer.log('[SWISSEPH][IOS] bundledFramework=$bundledFramework');
      developer.log(
        '[SWISSEPH][IOS] exists=${File(bundledFramework).existsSync()}',
      );

      if (File(bundledFramework).existsSync()) {
        developer.log('[SWISSEPH][IOS] LOADING BUNDLED FRAMEWORK');
        return SwissEph(bundledFramework);
      }

      throw StateError(
        'Swiss Ephemeris framework not found at: $bundledFramework',
      );
    }

    if (Platform.isMacOS) {
      final executable = File(Platform.resolvedExecutable);

      // macOS:
      // <App>.app/Contents/MacOS/<executable>
      // <App>.app/Contents/Frameworks/swisseph.framework/swisseph
      final contentsDirectory = executable.parent.parent;

      final bundledFramework =
          '${contentsDirectory.path}/Frameworks/swisseph.framework/swisseph';

      developer.log('[SWISSEPH][MACOS] bundledFramework=$bundledFramework');

      if (File(bundledFramework).existsSync()) {
        developer.log('[SWISSEPH][MACOS] LOADING BUNDLED FRAMEWORK');
        return SwissEph(bundledFramework);
      }
    }

    // Development fallback for platforms where the native bundle path
    // is not available.
    return SwissEph.load();
  }

  PlanetPosition _planetPosition(
    String planet,
    double longitude,
    double longitudeSpeed,
    double ascendant,
  ) {
    final signIndex = (longitude / 30.0).floor();

    /*
     * Whole-sign house:
     *
     * Ascendant sign = 1st house.
     */
    final ascendantSignIndex = (ascendant / 30.0).floor();

    final house = ((signIndex - ascendantSignIndex) % 12 + 12) % 12 + 1;

    return PlanetPosition(
      planet: planet,
      sign: _signFromLongitude(longitude),
      house: house,
      longitude: longitude,
      degree: _degreeWithinSign(longitude),
      retrograde: longitudeSpeed < 0,
      nakshatra: _nakshatra(longitude),
      nakshatraPada: _nakshatraPada(longitude),
    );
  }

  List<RashiHouse> _buildWholeSignChart(
    double ascendant,
    List<PlanetPosition> planets,
  ) {
    final ascendantSignIndex = (ascendant / 30.0).floor();

    final houses = <RashiHouse>[];

    for (int house = 1; house <= 12; house++) {
      final signIndex = (ascendantSignIndex + house - 1) % 12;

      final sign = _signNames[signIndex];

      final housePlanets = planets
          .where((planet) => planet.house == house)
          .toList();

      houses.add(RashiHouse(house: house, sign: sign, planets: housePlanets));
    }

    return houses;
  }

  _BirthTime _parseBirthTime(String value) {
    final normalized = value.trim().toUpperCase();

    final isPm = normalized.contains('PM');
    final isAm = normalized.contains('AM');

    final clean = normalized.replaceAll('AM', '').replaceAll('PM', '').trim();

    final parts = clean.split(':');

    int hour = int.parse(parts[0]);
    final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
    final second = parts.length > 2 ? int.parse(parts[2]) : 0;

    if (isPm && hour < 12) {
      hour += 12;
    }

    if (isAm && hour == 12) {
      hour = 0;
    }

    return _BirthTime(hour: hour, minute: minute, second: second);
  }

  DateTime _localToUtc(
    int year,
    int month,
    int day,
    int hour,
    int minute,
    int second,
    String timezone,
  ) {
    /*
     * Convert a birth date/time expressed in the supplied IANA
     * timezone into UTC using the timezone database.
     *
     * This is intentionally date-aware so DST is handled correctly.
     *
     * Examples:
     *   America/Chicago       -> CDT (-05:00) during summer
     *   America/Chicago       -> CST (-06:00) during winter
     *   America/Los_Angeles   -> PDT (-07:00) during summer
     *   America/Los_Angeles   -> PST (-08:00) during winter
     *   America/New_York      -> EDT (-04:00) during summer
     *   Asia/Kolkata          -> IST (+05:30), no DST
     */

    final location = tz.getLocation(timezone.trim());

    final local = tz.TZDateTime(
      location,
      year,
      month,
      day,
      hour,
      minute,
      second,
    );

    return local.toUtc();
  }

  double _normalize(double value) {
    var result = value % 360.0;

    if (result < 0) {
      result += 360.0;
    }

    return result;
  }

  double _degreeWithinSign(double longitude) {
    return longitude % 30.0;
  }

  String _signFromLongitude(double longitude) {
    final index = (longitude / 30.0).floor();
    return _signNames[index];
  }

  String _nakshatra(double longitude) {
    /*
     * 27 Nakshatras.
     *
     * Each Nakshatra = 13°20'
     */
    const nakshatras = <String>[
      'Ashwini',
      'Bharani',
      'Krittika',
      'Rohini',
      'Mrigashira',
      'Ardra',
      'Punarvasu',
      'Pushya',
      'Ashlesha',
      'Magha',
      'Purva Phalguni',
      'Uttara Phalguni',
      'Hasta',
      'Chitra',
      'Swati',
      'Vishakha',
      'Anuradha',
      'Jyeshtha',
      'Mula',
      'Purva Ashadha',
      'Uttara Ashadha',
      'Shravana',
      'Dhanishtha',
      'Shatabhisha',
      'Purva Bhadrapada',
      'Uttara Bhadrapada',
      'Revati',
    ];

    final index = (longitude / (360.0 / 27.0)).floor();

    return nakshatras[index];
  }

  int _nakshatraPada(double longitude) {
    final padaSize = 360.0 / 108.0;

    final index = (longitude / padaSize).floor();

    return (index % 4) + 1;
  }

  static const List<String> _signNames = <String>[
    'Aries',
    'Taurus',
    'Gemini',
    'Cancer',
    'Leo',
    'Virgo',
    'Libra',
    'Scorpio',
    'Sagittarius',
    'Capricorn',
    'Aquarius',
    'Pisces',
  ];
}

class _PlanetDefinition {
  final String name;
  final int body;

  const _PlanetDefinition(this.name, this.body);
}

class _BirthTime {
  final int hour;
  final int minute;
  final int second;

  const _BirthTime({
    required this.hour,
    required this.minute,
    required this.second,
  });
}
