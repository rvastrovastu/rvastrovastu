import 'dart:io';

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

      final utc = _localToUtc(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
        time.second,
        input.timezone,
      );

      final jd = swe.utcToJd(
        utc.year,
        utc.month,
        utc.day,
        utc.hour,
        utc.minute,
        utc.second.toDouble(),
      );

      final jdUt = jd.ut1;

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

      final moonNakshatra = _nakshatra(moon.degree);
      final moonPada = _nakshatraPada(moon.degree);

      final rashiHouses = _buildWholeSignChart(ascendant, planets);

      return Kundali(
        ayanamsa: ayanamsa,
        ascendant: _signFromLongitude(ascendant),
        ascendantDegree: _degreeWithinSign(ascendant),
        moonLongitude: moon.degree,
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
  /// We therefore resolve the path from the running application executable.
  Future<SwissEph> _loadSwissEph() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final executable = File(Platform.resolvedExecutable);

      final appBundle = executable.parent.path;

      final bundledFramework =
          '$appBundle/Frameworks/swisseph.framework/swisseph';

      if (File(bundledFramework).existsSync()) {
        return SwissEph(bundledFramework);
      }
    }

    // Development fallback:
    // SwissEph.load() searches .dart_tool for the build-hook output.
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
          .map((planet) => planet.planet)
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
     * Supports common timezone formats:
     *
     * America/Chicago
     * America/New_York
     * Asia/Kolkata
     * -5
     * 5.5
     *
     * For IANA timezone names, the current implementation
     * requires the timezone offset to be supplied by the
     * Birth Profile location layer.
     */

    final offset = _timezoneOffset(timezone);

    final local = DateTime.utc(year, month, day, hour, minute, second);

    return local.subtract(Duration(minutes: (offset * 60).round()));
  }

  double _timezoneOffset(String timezone) {
    final value = timezone.trim();

    final parsed = double.tryParse(value);

    if (parsed != null) {
      return parsed;
    }

    /*
     * Common offsets.
     *
     * The Birth Profile should eventually provide the exact
     * historical UTC offset for the birth location/date.
     */
    const offsets = <String, double>{
      'Asia/Kolkata': 5.5,
      'Asia/Calcutta': 5.5,
      'America/Chicago': -6.0,
      'America/New_York': -5.0,
      'America/Denver': -7.0,
      'America/Los_Angeles': -8.0,
      'UTC': 0.0,
    };

    return offsets[value] ?? 0.0;
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
