import '../entities/sade_sati.dart';

abstract class SaturnTransitRepository {
  /// Sidereal (Lahiri) sign periods of Saturn between [fromUtc] and
  /// [toUtc], in chronological order. The first period starts at [fromUtc]
  /// and the last ends at [toUtc]; ingress times are accurate to ~1 hour.
  Future<List<SaturnSignPeriod>> saturnSignPeriods({
    required DateTime fromUtc,
    required DateTime toUtc,
  });
}
