import 'package:swisseph/swisseph.dart';

import '../../core/astro/swiss_eph_loader.dart';

/// Finds when the Sun reaches a sidereal (Lahiri) longitude.
abstract class SolarReturnFinder {
  /// The moment closest to [nearUtc] when the Sun is at [sunLongitude].
  Future<DateTime> find(double sunLongitude, DateTime nearUtc);
}

class SwissSolarReturnFinder implements SolarReturnFinder {
  static const double _unixEpochJd = 2440587.5;
  static const double _meanDailyMotion = 0.9856474;

  @override
  Future<DateTime> find(double sunLongitude, DateTime nearUtc) async {
    final swe = await loadSwissEph();
    try {
      swe.setSidMode(seSidmLahiri);
      var jd =
          _unixEpochJd +
          nearUtc.toUtc().millisecondsSinceEpoch / Duration.millisecondsPerDay;
      for (var i = 0; i < 12; i++) {
        final lon = swe
            .calcUt(jd, seSun, seFlgSwiEph | seFlgSidereal)
            .longitude;
        final diff = ((sunLongitude - lon) % 360 + 540) % 360 - 180;
        jd += diff / _meanDailyMotion;
        if (diff.abs() < 1e-6) break;
      }
      return DateTime.fromMillisecondsSinceEpoch(
        ((jd - _unixEpochJd) * Duration.millisecondsPerDay).round(),
        isUtc: true,
      );
    } finally {
      swe.close();
    }
  }
}
