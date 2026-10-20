import '../entities/transit.dart';

abstract class TransitRepository {
  /// Sidereal (Lahiri) sign periods for each slow planet between [fromUtc]
  /// and [toUtc]. The first period of each list starts at [fromUtc] and the
  /// last ends at [toUtc].
  Future<Map<TransitPlanet, List<PlanetSignPeriod>>> signPeriods({
    required DateTime fromUtc,
    required DateTime toUtc,
  });
}
