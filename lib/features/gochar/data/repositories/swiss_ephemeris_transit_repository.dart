import 'dart:io';

import 'package:swisseph/swisseph.dart';

import '../../domain/entities/transit.dart';
import '../../domain/repositories/transit_repository.dart';

/// Sign ingresses of Jupiter, Saturn and the mean lunar node, found with
/// the same 5-day scan + 1-hour bisection as the Sade Sati calculation.
/// Ketu mirrors Rahu six signs away.
class SwissEphemerisTransitRepository implements TransitRepository {
  static const int _flags = seFlgSwiEph | seFlgSidereal;
  static const double _stepDays = 5;
  static const double _precisionDays = 1 / 24;
  static const double _unixEpochJd = 2440587.5;

  @override
  Future<Map<TransitPlanet, List<PlanetSignPeriod>>> signPeriods({
    required DateTime fromUtc,
    required DateTime toUtc,
  }) async {
    if (!toUtc.isAfter(fromUtc)) {
      throw ArgumentError('toUtc must be after fromUtc.');
    }

    final swe = await _loadSwissEph();
    try {
      swe.setSidMode(seSidmLahiri);

      List<PlanetSignPeriod> scan(TransitPlanet planet, int body) {
        int signAt(double jd) {
          final value = swe.calcUt(jd, body, _flags).longitude % 360;
          return ((value < 0 ? value + 360 : value) / 30).floor() % 12;
        }

        final startJd = _toJd(fromUtc);
        final endJd = _toJd(toUtc);
        final periods = <PlanetSignPeriod>[];
        var current = signAt(startJd);
        var periodStart = startJd;
        var jd = startJd;

        while (jd < endJd) {
          final next = (jd + _stepDays) > endJd ? endJd : jd + _stepDays;
          final sign = signAt(next);
          if (sign != current) {
            var low = jd;
            var high = next;
            while (high - low > _precisionDays) {
              final mid = (low + high) / 2;
              if (signAt(mid) == current) {
                low = mid;
              } else {
                high = mid;
              }
            }
            periods.add(
              PlanetSignPeriod(
                planet: planet,
                signIndex: current,
                start: _fromJd(periodStart),
                end: _fromJd(high),
              ),
            );
            current = sign;
            periodStart = high;
          }
          jd = next;
        }

        periods.add(
          PlanetSignPeriod(
            planet: planet,
            signIndex: current,
            start: _fromJd(periodStart),
            end: toUtc,
          ),
        );
        return periods;
      }

      final rahu = scan(TransitPlanet.rahu, seMeanNode);

      return {
        TransitPlanet.jupiter: scan(TransitPlanet.jupiter, seJupiter),
        TransitPlanet.saturn: scan(TransitPlanet.saturn, seSaturn),
        TransitPlanet.rahu: rahu,
        TransitPlanet.ketu: [
          for (final p in rahu)
            PlanetSignPeriod(
              planet: TransitPlanet.ketu,
              signIndex: (p.signIndex + 6) % 12,
              start: p.start,
              end: p.end,
            ),
        ],
      };
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
