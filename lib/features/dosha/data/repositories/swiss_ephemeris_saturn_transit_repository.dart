import 'dart:io';

import 'package:swisseph/swisseph.dart';

import '../../domain/entities/sade_sati.dart';
import '../../domain/repositories/saturn_transit_repository.dart';

/// Finds Saturn's sidereal sign ingresses with Swiss Ephemeris.
///
/// Saturn moves at most ~0.13°/day, so a 5-day step can never skip a whole
/// sign. Each sign change found by the scan is refined by bisection to
/// within an hour. Retrograde re-entries are captured as separate periods.
///
/// Verified against the known Lahiri ingresses: Capricorn 24 Jan 2020,
/// Aquarius 29 Apr 2022 / 17 Jan 2023, Pisces 29 Mar 2025.
class SwissEphemerisSaturnTransitRepository implements SaturnTransitRepository {
  static const int _flags = seFlgSwiEph | seFlgSidereal;
  static const double _stepDays = 5;
  static const double _precisionDays = 1 / 24;
  static const double _unixEpochJd = 2440587.5;

  @override
  Future<List<SaturnSignPeriod>> saturnSignPeriods({
    required DateTime fromUtc,
    required DateTime toUtc,
  }) async {
    if (!toUtc.isAfter(fromUtc)) {
      throw ArgumentError('toUtc must be after fromUtc.');
    }

    final swe = await _loadSwissEph();

    try {
      swe.setSidMode(seSidmLahiri);

      int signAt(double jd) {
        final longitude = swe.calcUt(jd, seSaturn, _flags).longitude;
        final normalized = ((longitude % 360) + 360) % 360;
        return (normalized / 30).floor() % 12;
      }

      final startJd = _toJd(fromUtc);
      final endJd = _toJd(toUtc);

      final periods = <SaturnSignPeriod>[];
      var currentSign = signAt(startJd);
      var periodStartJd = startJd;
      var jd = startJd;

      while (jd < endJd) {
        final next = (jd + _stepDays) > endJd ? endJd : jd + _stepDays;
        final sign = signAt(next);

        if (sign != currentSign) {
          var low = jd;
          var high = next;
          while (high - low > _precisionDays) {
            final mid = (low + high) / 2;
            if (signAt(mid) == currentSign) {
              low = mid;
            } else {
              high = mid;
            }
          }

          periods.add(
            SaturnSignPeriod(
              signIndex: currentSign,
              start: _fromJd(periodStartJd),
              end: _fromJd(high),
            ),
          );
          currentSign = signAt(high);
          periodStartJd = high;
        }

        jd = next;
      }

      periods.add(
        SaturnSignPeriod(
          signIndex: currentSign,
          start: _fromJd(periodStartJd),
          end: toUtc,
        ),
      );

      return periods;
    } finally {
      swe.close();
    }
  }

  static double _toJd(DateTime utc) =>
      _unixEpochJd +
      utc.toUtc().millisecondsSinceEpoch / Duration.millisecondsPerDay;

  static DateTime _fromJd(double jd) => DateTime.fromMillisecondsSinceEpoch(
    ((jd - _unixEpochJd) * Duration.millisecondsPerDay).round(),
    isUtc: true,
  );

  /// Mirrors the bundle lookup in `SwissEphemerisAstrologyRepository`:
  /// iOS/macOS ship Swiss Ephemeris as an embedded framework.
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
