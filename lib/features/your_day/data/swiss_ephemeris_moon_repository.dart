import 'dart:io';

import 'package:swisseph/swisseph.dart';

import '../domain/day_strength.dart';

/// Sidereal (Lahiri) Moon position and its next nakshatra and sign change.
class SwissEphemerisMoonRepository {
  static const int _flags = seFlgSwiEph | seFlgSidereal;
  static const double _unixEpochJd = 2440587.5;
  static const double _stepDays = 1 / 12; // 2 hours
  static const double _precisionDays = 1 / 1440; // 1 minute

  Future<MoonNow> moonAt(DateTime instant) async {
    final swe = await _loadSwissEph();
    try {
      swe.setSidMode(seSidmLahiri);
      double longitude(double jd) => swe.calcUt(jd, seMoon, _flags).longitude;

      final start = _toJd(instant);
      final now = longitude(start);

      // First instant after start where index changes value.
      double nextChange(int Function(double) index) {
        final current = index(now);
        var low = start;
        var high = start + _stepDays;
        // The Moon spends at most ~2.7 days in a sign.
        while (index(longitude(high)) == current && high - start < 4) {
          low = high;
          high += _stepDays;
        }
        while (high - low > _precisionDays) {
          final mid = (low + high) / 2;
          if (index(longitude(mid)) == current) {
            low = mid;
          } else {
            high = mid;
          }
        }
        return high;
      }

      return MoonNow(
        longitude: now,
        nakshatraEndsUtc: _fromJd(nextChange(nakshatraIndexOf)),
        signEndsUtc: _fromJd(nextChange(signIndexOf)),
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
