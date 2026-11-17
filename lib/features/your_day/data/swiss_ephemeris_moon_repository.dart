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

  /// The solar or lunar eclipse whose New or Full Moon falls between [from]
  /// and [to] (local instants), or null. A New Moon with the Moon close to
  /// the node is a solar eclipse; a Full Moon likewise is a lunar eclipse.
  Future<EclipseHit?> eclipseBetween(DateTime from, DateTime to) async {
    final swe = await _loadSwissEph();
    try {
      double elongation(double jd) =>
          swe.calcUt(jd, seMoon, seFlgSwiEph).longitude -
          swe.calcUt(jd, seSun, seFlgSwiEph).longitude;

      // Signed distance from [target], wrapped to (-180, 180].
      double offset(double jd, double target) {
        var d = (elongation(jd) - target) % 360;
        if (d > 180) d -= 360;
        return d;
      }

      final start = _toJd(from);
      final end = _toJd(to);
      for (final (target, solar) in [(0.0, true), (180.0, false)]) {
        final a = offset(start, target);
        final b = offset(end, target);
        // A sign change without a wrap means the syzygy is inside the window.
        if (a * b > 0 || (a - b).abs() > 90) continue;

        var low = start;
        var high = end;
        for (var i = 0; i < 40; i++) {
          final mid = (low + high) / 2;
          if (offset(mid, target) * a > 0) {
            low = mid;
          } else {
            high = mid;
          }
        }
        final at = (low + high) / 2;
        final latitude = swe.calcUt(at, seMoon, seFlgSwiEph).latitude.abs();
        // Moon's latitude at the syzygy: close to the node means an eclipse.
        if (latitude < (solar ? 1.5 : 1.1)) {
          return EclipseHit(time: _fromJd(at), solar: solar);
        }
      }
      return null;
    } finally {
      swe.close();
    }
  }

  /// The sidereal sign (0 = Aries) the Sun enters between [from] and [to]
  /// (local instants), or null if it stays in one sign.
  Future<int?> sunEntersSignBetween(DateTime from, DateTime to) async {
    final swe = await _loadSwissEph();
    try {
      swe.setSidMode(seSidmLahiri);
      int signAt(DateTime t) =>
          (swe.calcUt(_toJd(t), seSun, _flags).longitude / 30).floor() % 12;
      final before = signAt(from);
      final after = signAt(to);
      return before == after ? null : after;
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

    // Android: Flutter bundles the library inside the app as
    // libswisseph.so, which opens by name.
    if (Platform.isAndroid) {
      try {
        return SwissEph('libswisseph.so');
      } catch (_) {}
    }
    return SwissEph.load();
  }
}

/// An eclipse at a New or Full Moon: [solar] is true for a solar eclipse.
class EclipseHit {
  final DateTime time;
  final bool solar;

  const EclipseHit({required this.time, required this.solar});
}
