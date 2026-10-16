import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:swisseph/swisseph.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/daily_panchang.dart';
import '../../domain/repositories/daily_panchang_repository.dart';

class _RiseSetEvent {
  final double transitTime;
  final String formatted;

  const _RiseSetEvent({required this.transitTime, required this.formatted});
}

class SwissEphemerisDailyPanchangRepository implements DailyPanchangRepository {
  static const int _siderealFlags = seFlgSwiEph | seFlgSpeed | seFlgSidereal;

  @override
  Future<DailyPanchang> calculate({
    required DateTime date,
    required double latitude,
    required double longitude,
    required String timezone,
  }) async {
    final swe = await _loadSwissEph();

    try {
      swe.setSidMode(seSidmLahiri);

      /*
       * Resolve the requested IANA timezone and construct local noon
       * using the timezone database. TZDateTime automatically applies
       * the correct historical/DST offset for this calendar date.
       */
      final location = tz.getLocation(timezone);

      final localMidday = tz.TZDateTime(
        location,
        date.year,
        date.month,
        date.day,
        12,
      );

      final utcMidday = localMidday.toUtc();

      final jd = swe.utcToJd(
        utcMidday.year,
        utcMidday.month,
        utcMidday.day,
        utcMidday.hour,
        utcMidday.minute,
        utcMidday.second.toDouble(),
      );

      final jdUt = jd.ut1;

      /*
       * Daily Panchang astronomical values are evaluated at the
       * actual LOCAL SUNRISE instant.
       *
       * We therefore calculate sunrise first and retain the
       * Swiss Ephemeris transitTime (Julian Day / UT instant).
       */
      final sunriseEvent = _riseSetEvent(
        swe: swe,
        jdUt: jdUt - 0.5,
        body: seSun,
        latitude: latitude,
        longitude: longitude,
        calcFlag: seCalcRise,
        location: location,
      );

      final sunrise = sunriseEvent.formatted;

      if (sunriseEvent.transitTime == 0) {
        final sunset = _riseSet(
          swe: swe,
          jdUt: jdUt - 0.5,
          body: seSun,
          latitude: latitude,
          longitude: longitude,
          calcFlag: seCalcSet,
          location: location,
        );

        final moonrise = _riseSet(
          swe: swe,
          jdUt: jdUt - 0.5,
          body: seMoon,
          latitude: latitude,
          longitude: longitude,
          calcFlag: seCalcRise,
          location: location,
        );

        return DailyPanchang(
          date: date,
          tithi: '—',
          nakshatra: '—',
          yoga: '—',
          sunrise: sunrise,
          sunset: sunset,
          moonrise: moonrise,
          rahuKaal: '—',
          muhurat: '—',
        );
      }

      /*
       * Use the exact sunrise Julian Day for Sun/Moon longitude.
       *
       * This replaces the previous local-noon calculation.
       */
      final sunriseJdUt = sunriseEvent.transitTime;

      final sun = swe.calcUt(sunriseJdUt, seSun, _siderealFlags);

      final moon = swe.calcUt(sunriseJdUt, seMoon, _siderealFlags);

      final sunLongitude = _normalize(sun.longitude);
      final moonLongitude = _normalize(moon.longitude);

      /*
       * Tithi:
       *
       * Angular separation of Moon from Sun.
       * 12 degrees = one Tithi.
       */
      final separation = _normalize(moonLongitude - sunLongitude);

      final tithiIndex = (separation / 12.0).floor();

      /*
       * Nakshatra:
       *
       * 13°20' = 13.333333°.
       */
      final nakshatraIndex = (moonLongitude / (360.0 / 27.0)).floor();

      /*
       * Yoga:
       *
       * Sun + Moon longitude.
       * Each Yoga = 13°20'.
       */
      final yogaLongitude = _normalize(sunLongitude + moonLongitude);

      final yogaIndex = (yogaLongitude / (360.0 / 27.0)).floor();

      final sunset = _riseSet(
        swe: swe,
        jdUt: jdUt - 0.5,
        body: seSun,
        latitude: latitude,
        longitude: longitude,
        calcFlag: seCalcSet,
        location: location,
      );

      final moonrise = _riseSet(
        swe: swe,
        jdUt: jdUt - 0.5,
        body: seMoon,
        latitude: latitude,
        longitude: longitude,
        calcFlag: seCalcRise,
        location: location,
      );

      debugPrint(
        '[PANCHANG][REPOSITORY] '
        'sunrise=$sunrise '
        'sunset=$sunset '
        'moonrise=$moonrise',
      );

      final rahuKaal = _calculateRahuKaal(date.weekday, sunrise, sunset);

      final muhurat = _calculateAbhijit(date.weekday, sunrise, sunset);

      return DailyPanchang(
        date: date,
        tithi: _tithiName(tithiIndex),
        nakshatra: _nakshatraName(nakshatraIndex),
        yoga: _yogaName(yogaIndex),
        sunrise: sunrise,
        sunset: sunset,
        moonrise: moonrise,
        rahuKaal: rahuKaal,
        muhurat: muhurat,
      );
    } finally {
      swe.close();
    }
  }

  /// Resolve the bundled Swiss Ephemeris native library.
  ///
  /// iOS Flutter app bundle:
  /// `<Runner.app>`/Runner
  /// `<Runner.app>`/Frameworks/swisseph.framework/swisseph
  Future<SwissEph> _loadSwissEph() async {
    if (Platform.isIOS) {
      final executable = File(Platform.resolvedExecutable);
      final appDirectory = executable.parent;

      final bundledFramework =
          '${appDirectory.path}/Frameworks/swisseph.framework/swisseph';

      developer.log('[PANCHANG][SWISSEPH][IOS] executable=${executable.path}');
      developer.log(
        '[PANCHANG][SWISSEPH][IOS] bundledFramework=$bundledFramework',
      );
      developer.log(
        '[PANCHANG][SWISSEPH][IOS] exists=${File(bundledFramework).existsSync()}',
      );

      if (File(bundledFramework).existsSync()) {
        developer.log('[PANCHANG][SWISSEPH][IOS] LOADING BUNDLED FRAMEWORK');
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

      developer.log(
        '[PANCHANG][SWISSEPH][MACOS] bundledFramework=$bundledFramework',
      );

      if (File(bundledFramework).existsSync()) {
        developer.log('[PANCHANG][SWISSEPH][MACOS] LOADING BUNDLED FRAMEWORK');
        return SwissEph(bundledFramework);
      }
    }

    return SwissEph.load();
  }

  _RiseSetEvent _riseSetEvent({
    required SwissEph swe,
    required double jdUt,
    required int body,
    required double latitude,
    required double longitude,
    required int calcFlag,
    required tz.Location location,
  }) {
    final result = swe.riseTrans(
      jdUt,
      body,
      rsmi: calcFlag,
      geolon: longitude,
      geolat: latitude,
    );

    if (result.returnFlag < 0 || result.transitTime == 0) {
      return const _RiseSetEvent(transitTime: 0, formatted: '—');
    }

    final local = _julianToLocal(result.transitTime, location);

    return _RiseSetEvent(
      transitTime: result.transitTime,
      formatted: _formatTime(local),
    );
  }

  String _riseSet({
    required SwissEph swe,
    required double jdUt,
    required int body,
    required double latitude,
    required double longitude,
    required int calcFlag,
    required tz.Location location,
  }) {
    return _riseSetEvent(
      swe: swe,
      jdUt: jdUt,
      body: body,
      latitude: latitude,
      longitude: longitude,
      calcFlag: calcFlag,
      location: location,
    ).formatted;
  }

  DateTime _julianToLocal(double jd, tz.Location location) {
    /*
     * Swiss Ephemeris returns the rise/set transit time in UT.
     *
     * Convert Julian Day -> UTC first, then let the IANA timezone
     * database convert UTC -> local time. This automatically applies
     * the correct DST/historical offset for the requested date.
     */
    final daysSinceEpoch = jd - 2440587.5;

    final milliseconds = (daysSinceEpoch * Duration.millisecondsPerDay).round();

    final utc = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

    return tz.TZDateTime.from(utc, location);
  }

  String _formatTime(DateTime value) {
    final hour = value.hour;
    final minute = value.minute;

    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;

    final suffix = hour >= 12 ? 'PM' : 'AM';

    return '${displayHour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')} $suffix';
  }

  String _calculateRahuKaal(int weekday, String sunrise, String sunset) {
    if (sunrise == '—' || sunset == '—') {
      return '—';
    }

    final rise = _parseDisplayTime(sunrise);
    final set = _parseDisplayTime(sunset);

    final daylightMinutes = set.difference(rise).inMinutes;

    if (daylightMinutes <= 0) {
      return '—';
    }

    /*
     * Traditional Rahu Kaal daytime segments:
     *
     * Sunday    = 8
     * Monday    = 2
     * Tuesday   = 7
     * Wednesday = 5
     * Thursday  = 6
     * Friday    = 4
     * Saturday  = 3
     *
     * DateTime.weekday:
     * Monday = 1 ... Sunday = 7
     */
    const segments = <int, int>{7: 8, 1: 2, 2: 7, 3: 5, 4: 6, 5: 4, 6: 3};

    final segment = segments[weekday];

    if (segment == null) {
      return '—';
    }

    final segmentLength = daylightMinutes / 8.0;

    final startMinutes = ((segment - 1) * segmentLength).round();

    final endMinutes = (segment * segmentLength).round();

    final rahuStart = rise.add(Duration(minutes: startMinutes));

    final rahuEnd = rise.add(Duration(minutes: endMinutes));

    return '${_formatTime(rahuStart)} – ${_formatTime(rahuEnd)}';
  }

  String _calculateAbhijit(int weekday, String sunrise, String sunset) {
    /*
     * Abhijit is traditionally centered around local solar noon.
     *
     * Wednesday is generally considered especially favorable,
     * but the time window itself is calculated for every day.
     */
    if (sunrise == '—' || sunset == '—') {
      return '—';
    }

    final rise = _parseDisplayTime(sunrise);
    final set = _parseDisplayTime(sunset);

    final daylightMinutes = set.difference(rise).inMinutes;

    if (daylightMinutes <= 0) {
      return '—';
    }

    /*
     * Traditional Abhijit Muhurat:
     *
     * Daylight is divided into 15 equal Muhurta segments.
     * Abhijit Muhurat is the 8th segment.
     *
     * Therefore:
     *   start = sunrise + (7 / 15) * daylight
     *   end   = sunrise + (8 / 15) * daylight
     *
     * Do not use a fixed +/-24 minute window because daylight
     * duration varies by date and location.
     */
    final segmentLength = daylightMinutes / 15.0;

    final startMinutes = (7 * segmentLength).round();
    final endMinutes = (8 * segmentLength).round();

    final start = rise.add(Duration(minutes: startMinutes));
    final end = rise.add(Duration(minutes: endMinutes));

    return '${_formatTime(start)} – ${_formatTime(end)}';
  }

  DateTime _parseDisplayTime(String value) {
    final parts = value.split(' ');
    final time = parts[0];
    final suffix = parts[1];

    final hm = time.split(':');

    var hour = int.parse(hm[0]);
    final minute = int.parse(hm[1]);

    if (suffix == 'PM' && hour != 12) {
      hour += 12;
    }

    if (suffix == 'AM' && hour == 12) {
      hour = 0;
    }

    return DateTime.utc(2000, 1, 1, hour, minute);
  }

  double _normalize(double value) {
    var result = value % 360.0;

    if (result < 0) {
      result += 360.0;
    }

    return result;
  }

  String _tithiName(int index) {
    const names = <String>[
      'Shukla Pratipada',
      'Shukla Dwitiya',
      'Shukla Tritiya',
      'Shukla Chaturthi',
      'Shukla Panchami',
      'Shukla Shashthi',
      'Shukla Saptami',
      'Shukla Ashtami',
      'Shukla Navami',
      'Shukla Dashami',
      'Shukla Ekadashi',
      'Shukla Dwadashi',
      'Shukla Trayodashi',
      'Shukla Chaturdashi',
      'Purnima',
      'Krishna Pratipada',
      'Krishna Dwitiya',
      'Krishna Tritiya',
      'Krishna Chaturthi',
      'Krishna Panchami',
      'Krishna Shashthi',
      'Krishna Saptami',
      'Krishna Ashtami',
      'Krishna Navami',
      'Krishna Dashami',
      'Krishna Ekadashi',
      'Krishna Dwadashi',
      'Krishna Trayodashi',
      'Krishna Chaturdashi',
      'Amavasya',
    ];

    return names[index.clamp(0, 29)];
  }

  String _nakshatraName(int index) {
    const names = <String>[
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

    return names[index.clamp(0, 26)];
  }

  String _yogaName(int index) {
    const names = <String>[
      'Vishkambha',
      'Priti',
      'Ayushman',
      'Saubhagya',
      'Shobhana',
      'Atiganda',
      'Sukarma',
      'Dhriti',
      'Shula',
      'Ganda',
      'Vriddhi',
      'Dhruva',
      'Vyaghata',
      'Harshana',
      'Vajra',
      'Siddhi',
      'Vyatipata',
      'Variyana',
      'Parigha',
      'Shiva',
      'Siddha',
      'Sadhya',
      'Shubha',
      'Shukla',
      'Brahma',
      'Indra',
      'Vaidhriti',
    ];

    return names[index.clamp(0, 26)];
  }
}
