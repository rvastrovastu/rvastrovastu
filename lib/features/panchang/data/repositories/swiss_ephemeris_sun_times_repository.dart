import 'dart:io';

import 'package:swisseph/swisseph.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/day_divisions.dart';

/// Sunrise, sunset and the next sunrise for a local calendar date, using
/// the same Swiss Ephemeris rise/set settings as the daily Panchang.
class SwissEphemerisSunTimesRepository {
  static const double _unixEpochJd = 2440587.5;

  /// Returns null where the Sun does not rise or set that day (polar
  /// regions), since no day can be divided there.
  Future<SunTimes?> sunTimes({
    required DateTime date,
    required double latitude,
    required double longitude,
    required String timezone,
  }) async {
    final swe = await _loadSwissEph();
    try {
      final location = tz.getLocation(timezone);
      final midnight = tz.TZDateTime(
        location,
        date.year,
        date.month,
        date.day,
      );

      double? next(double fromJd, int flag) {
        try {
          final result = swe.riseTrans(
            fromJd,
            seSun,
            rsmi: flag,
            geolon: longitude,
            geolat: latitude,
          );
          if (result.returnFlag < 0 || result.transitTime == 0) return null;
          return result.transitTime;
        } catch (_) {
          // The binding throws when the Sun is circumpolar that day.
          return null;
        }
      }

      final sunrise = next(_toJd(midnight), seCalcRise);
      if (sunrise == null) return null;
      final sunset = next(sunrise, seCalcSet);
      if (sunset == null) return null;
      final nextSunrise = next(sunset, seCalcRise);
      if (nextSunrise == null) return null;

      // Guard against a rise that belongs to the following date.
      final localRise = tz.TZDateTime.from(_fromJd(sunrise), location);
      if (localRise.day != date.day) return null;

      return SunTimes(
        sunrise: _fromJd(sunrise),
        sunset: _fromJd(sunset),
        nextSunrise: _fromJd(nextSunrise),
      );
    } finally {
      swe.close();
    }
  }

  static double _toJd(DateTime instant) =>
      _unixEpochJd +
      instant.toUtc().millisecondsSinceEpoch / Duration.millisecondsPerDay;

  static DateTime _fromJd(double jd) => DateTime.fromMillisecondsSinceEpoch(
    ((jd - _unixEpochJd) * Duration.millisecondsPerDay).round(),
    isUtc: true,
  );

  Future<SwissEph> _loadSwissEph() async {
    if (Platform.isIOS) {
      final appDirectory = File(Platform.resolvedExecutable).parent;
      final framework =
          '${appDirectory.path}/Frameworks/swisseph.framework/swisseph';
      if (File(framework).existsSync()) return SwissEph(framework);
      throw StateError('Swiss Ephemeris framework not found at: $framework');
    }

    if (Platform.isMacOS) {
      final contents = File(Platform.resolvedExecutable).parent.parent;
      final framework =
          '${contents.path}/Frameworks/swisseph.framework/swisseph';
      if (File(framework).existsSync()) return SwissEph(framework);
    }

    return SwissEph.load();
  }
}
