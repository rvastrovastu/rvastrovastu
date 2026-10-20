import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/domain/entities/planet_position.dart';
import '../entities/manglik_result.dart';
import '../entities/zodiac_signs.dart';

/// Checks Manglik (Mangal / Kuja) dosha using whole-sign houses.
///
/// Mars in the 1st, 2nd, 4th, 7th, 8th or 12th house is checked from the
/// Lagna, the Moon and Venus — the three reference points most Vedic
/// matching guides use. A Lagna placement is reported as
/// [ManglikStatus.present]; a Moon- or Venus-only placement as
/// [ManglikStatus.mild].
class CheckManglikDosha {
  static const Set<int> manglikHouses = {1, 2, 4, 7, 8, 12};

  const CheckManglikDosha();

  ManglikResult call(Kundali kundali) {
    final mars = _planet(kundali, 'Mars');
    final moon = _planet(kundali, 'Moon');
    final venus = _planet(kundali, 'Venus');
    final jupiter = _planet(kundali, 'Jupiter');

    final lagnaIndex = _signIndex(kundali.ascendant, 'ascendant');
    final marsIndex = _signIndex(mars.sign, 'Mars');
    final moonIndex = _signIndex(moon.sign, 'Moon');
    final venusIndex = _signIndex(venus.sign, 'Venus');
    final jupiterIndex = _signIndex(jupiter.sign, 'Jupiter');

    final fromLagnaHouse = houseFrom(lagnaIndex, marsIndex);
    final fromMoonHouse = houseFrom(moonIndex, marsIndex);
    final fromVenusHouse = houseFrom(venusIndex, marsIndex);

    final fromLagna = manglikHouses.contains(fromLagnaHouse);
    final fromMoon = manglikHouses.contains(fromMoonHouse);
    final fromVenus = manglikHouses.contains(fromVenusHouse);

    final hasPlacement = fromLagna || fromMoon || fromVenus;

    final cancellations = hasPlacement
        ? _cancellations(
            marsIndex: marsIndex,
            moonIndex: moonIndex,
            jupiterIndex: jupiterIndex,
          )
        : const <ManglikCancellation>[];

    final ManglikStatus status;
    if (!hasPlacement) {
      status = ManglikStatus.none;
    } else if (cancellations.isNotEmpty) {
      status = ManglikStatus.cancelled;
    } else if (fromLagna) {
      status = ManglikStatus.present;
    } else {
      status = ManglikStatus.mild;
    }

    return ManglikResult(
      status: status,
      marsHouseFromLagna: fromLagnaHouse,
      marsHouseFromMoon: fromMoonHouse,
      marsHouseFromVenus: fromVenusHouse,
      fromLagna: fromLagna,
      fromMoon: fromMoon,
      fromVenus: fromVenus,
      marsSign: mars.sign,
      cancellations: cancellations,
    );
  }

  List<ManglikCancellation> _cancellations({
    required int marsIndex,
    required int moonIndex,
    required int jupiterIndex,
  }) {
    final result = <ManglikCancellation>[];

    // Aries (0), Scorpio (7) own signs; Capricorn (9) exaltation.
    if (marsIndex == 0 || marsIndex == 7 || marsIndex == 9) {
      result.add(ManglikCancellation.marsInOwnOrExaltedSign);
    }

    if (jupiterIndex == marsIndex) {
      result.add(ManglikCancellation.jupiterConjunctMars);
    } else if (const {5, 7, 9}.contains(houseFrom(jupiterIndex, marsIndex))) {
      result.add(ManglikCancellation.jupiterAspectsMars);
    }

    if (moonIndex == marsIndex) {
      result.add(ManglikCancellation.moonConjunctMars);
    }

    return result;
  }

  PlanetPosition _planet(Kundali kundali, String name) {
    for (final planet in kundali.planets) {
      if (planet.planet == name) return planet;
    }
    throw ArgumentError('Kundali is missing $name.');
  }

  int _signIndex(String sign, String label) {
    final index = zodiacSignIndex(sign);
    if (index < 0) {
      throw ArgumentError('Unknown sign for $label: "$sign".');
    }
    return index;
  }
}
