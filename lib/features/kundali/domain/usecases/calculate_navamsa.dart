import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/domain/entities/planet_position.dart';
import '../../../astrology/domain/entities/rashi_chart.dart';
import '../../../dosha/domain/entities/zodiac_signs.dart';

/// Navamsa (D9) chart with whole-sign houses from the Navamsa Lagna.
class NavamsaChart {
  final RashiChart chart;
  final String lagnaSign;

  /// Planets in the same sign in D1 and D9 (vargottama).
  final List<String> vargottama;

  const NavamsaChart({
    required this.chart,
    required this.lagnaSign,
    required this.vargottama,
  });
}

/// Each sign is divided into nine 3°20′ navamsas. Counting navamsas
/// continuously from 0° Aries and wrapping every 12 gives the standard
/// Parashari mapping (fire signs start from Aries, earth from Capricorn,
/// air from Libra, water from Cancer).
class CalculateNavamsa {
  static const double navamsaSpan = 30 / 9;

  const CalculateNavamsa();

  /// Navamsa sign index (Aries = 0) for a sidereal longitude.
  static int navamsaSignIndex(double longitude) {
    final normalized = ((longitude % 360) + 360) % 360;
    return (normalized / navamsaSpan).floor() % 12;
  }

  NavamsaChart call(Kundali kundali) {
    final ascendantIndex = zodiacSignIndex(kundali.ascendant);
    if (ascendantIndex < 0) {
      throw ArgumentError('Unknown ascendant sign: "${kundali.ascendant}".');
    }

    final ascendantLongitude = ascendantIndex * 30 + kundali.ascendantDegree;
    final lagnaIndex = navamsaSignIndex(ascendantLongitude);

    final planets = <PlanetPosition>[];
    final vargottama = <String>[];

    for (final planet in kundali.planets) {
      final signIndex = navamsaSignIndex(planet.longitude);
      final within = (planet.longitude % navamsaSpan) / navamsaSpan * 30;

      planets.add(
        PlanetPosition(
          planet: planet.planet,
          sign: zodiacSigns[signIndex],
          house: houseFrom(lagnaIndex, signIndex),
          longitude: signIndex * 30 + within,
          degree: within,
          retrograde: planet.retrograde,
        ),
      );

      if (zodiacSignIndex(planet.sign) == signIndex) {
        vargottama.add(planet.planet);
      }
    }

    final houses = [
      for (var house = 1; house <= 12; house++)
        RashiHouse(
          house: house,
          sign: zodiacSigns[(lagnaIndex + house - 1) % 12],
          planets: [
            for (final p in planets)
              if (p.house == house) p,
          ],
        ),
    ];

    return NavamsaChart(
      chart: RashiChart(houses: houses),
      lagnaSign: zodiacSigns[lagnaIndex],
      vargottama: vargottama,
    );
  }
}
