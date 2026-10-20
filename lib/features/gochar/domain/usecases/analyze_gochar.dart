import '../../../dosha/domain/entities/zodiac_signs.dart';
import '../entities/transit.dart';

/// Reads slow-planet transits from the natal Moon (Gochara).
///
/// Favourable houses from the Moon follow the classical rule found in
/// Phaladeepika and most Panchang guides: Jupiter in the 2nd, 5th, 7th, 9th
/// or 11th; Saturn, Rahu and Ketu in the 3rd, 6th or 11th.
class AnalyzeGochar {
  static const Map<TransitPlanet, Set<int>> favourableHouses = {
    TransitPlanet.jupiter: {2, 5, 7, 9, 11},
    TransitPlanet.saturn: {3, 6, 11},
    TransitPlanet.rahu: {3, 6, 11},
    TransitPlanet.ketu: {3, 6, 11},
  };

  static const Duration upcomingWindow = Duration(days: 730);

  const AnalyzeGochar();

  static TransitTone toneFor(TransitPlanet planet, int houseFromMoon) =>
      favourableHouses[planet]!.contains(houseFromMoon)
      ? TransitTone.favourable
      : TransitTone.challenging;

  GocharReport call({
    required String moonSign,
    required String lagnaSign,
    required Map<TransitPlanet, List<PlanetSignPeriod>> periods,
    required DateTime now,
  }) {
    final moonIndex = zodiacSignIndex(moonSign);
    final lagnaIndex = zodiacSignIndex(lagnaSign);
    if (moonIndex < 0 || lagnaIndex < 0) {
      throw ArgumentError('Unknown Moon or Lagna sign.');
    }

    final current = <TransitReading>[];
    final upcoming = <UpcomingIngress>[];
    final horizon = now.add(upcomingWindow);

    for (final planet in TransitPlanet.values) {
      final list = [...?periods[planet]]
        ..sort((a, b) => a.start.compareTo(b.start));
      if (list.isEmpty) continue;

      final index = list.indexWhere((p) => p.contains(now));
      if (index < 0) continue;

      final period = list[index];
      final next = index + 1 < list.length ? list[index + 1] : null;
      final houseFromMoon = houseFrom(moonIndex, period.signIndex);

      current.add(
        TransitReading(
          planet: planet,
          signIndex: period.signIndex,
          houseFromMoon: houseFromMoon,
          houseFromLagna: houseFrom(lagnaIndex, period.signIndex),
          tone: toneFor(planet, houseFromMoon),
          since: index == 0 ? null : period.start,
          until: next == null ? null : period.end,
          nextSignIndex: next?.signIndex,
        ),
      );

      for (final later in list.skip(index + 1)) {
        if (later.start.isAfter(horizon)) break;
        final house = houseFrom(moonIndex, later.signIndex);
        upcoming.add(
          UpcomingIngress(
            planet: planet,
            date: later.start,
            signIndex: later.signIndex,
            houseFromMoon: house,
            tone: toneFor(planet, house),
          ),
        );
      }
    }

    upcoming.sort((a, b) => a.date.compareTo(b.date));
    return GocharReport(current: current, upcoming: upcoming);
  }
}
