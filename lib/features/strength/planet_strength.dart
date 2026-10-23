import '../astrology/domain/entities/kundali.dart';
import '../dosha/domain/entities/zodiac_signs.dart';
import '../yogas/domain/usecases/detect_yogas.dart';

/// Shadbala factors that can be read from the birth chart, in virupas
/// (60 virupas = 1 rupa):
/// - Uchcha (exaltation) bala: distance from the deep debilitation point.
/// - Saptavargaja-style dignity in the Rashi: own, friend, neutral, enemy.
/// - Dig (directional) bala: closeness to the planet's strong angle.
/// - Naisargika (natural) bala: fixed.
/// - Paksha bala: benefics gain with a waxing Moon, malefics with waning.
/// - Chesta (motion) bala: retrograde planets are strongest.
/// Kala components that need the exact birth time against sunrise, and
/// Drik bala, are left out, so totals compare planets with each other
/// rather than against the classical minimums.
class PlanetStrength {
  final String planet;
  final double uchcha;
  final double dignity;
  final double dig;
  final double naisargika;
  final double paksha;
  final double chesta;

  const PlanetStrength({
    required this.planet,
    required this.uchcha,
    required this.dignity,
    required this.dig,
    required this.naisargika,
    required this.paksha,
    required this.chesta,
  });

  double get total => uchcha + dignity + dig + naisargika + paksha + chesta;

  /// In rupas.
  double get rupas => total / 60;
}

const _deepExaltation = {
  'Sun': 10.0,
  'Moon': 33.0,
  'Mars': 298.0,
  'Mercury': 165.0,
  'Jupiter': 95.0,
  'Venus': 357.0,
  'Saturn': 200.0,
};

const _naisargika = {
  'Sun': 60.0,
  'Moon': 51.43,
  'Venus': 42.86,
  'Jupiter': 34.29,
  'Mercury': 25.71,
  'Mars': 17.14,
  'Saturn': 8.57,
};

const _friends = {
  'Sun': {'Moon', 'Mars', 'Jupiter'},
  'Moon': {'Sun', 'Mercury'},
  'Mars': {'Sun', 'Moon', 'Jupiter'},
  'Mercury': {'Sun', 'Venus'},
  'Jupiter': {'Sun', 'Moon', 'Mars'},
  'Venus': {'Mercury', 'Saturn'},
  'Saturn': {'Mercury', 'Venus'},
};

const _enemies = {
  'Sun': {'Venus', 'Saturn'},
  'Moon': <String>{},
  'Mars': {'Mercury'},
  'Mercury': {'Moon'},
  'Jupiter': {'Mercury', 'Venus'},
  'Venus': {'Sun', 'Moon'},
  'Saturn': {'Sun', 'Moon', 'Mars'},
};

/// Degrees from the Lagna at which each planet has full directional
/// strength: Jupiter and Mercury in the 1st, Moon and Venus in the 4th,
/// Saturn in the 7th, Sun and Mars in the 10th.
const _digPoint = {
  'Jupiter': 0.0,
  'Mercury': 0.0,
  'Moon': 90.0,
  'Venus': 90.0,
  'Saturn': 180.0,
  'Sun': 270.0,
  'Mars': 270.0,
};

double _arc(double a, double b) {
  final d = ((a - b) % 360 + 360) % 360;
  return d > 180 ? 360 - d : d;
}

const strengthPlanets = [
  'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', //
];

/// Strength of the seven planets, strongest first.
List<PlanetStrength> calculatePlanetStrength(Kundali kundali) {
  final lagnaIndex = zodiacSignIndex(kundali.ascendant);
  final ascendant = lagnaIndex * 30 + kundali.ascendantDegree;
  double lon(String p) =>
      kundali.planets.firstWhere((x) => x.planet == p).longitude;

  // Waxing (Shukla) when the Moon is 0–180° ahead of the Sun.
  final elongation = ((lon('Moon') - lon('Sun')) % 360 + 360) % 360;
  final moonLight = elongation <= 180 ? elongation : 360 - elongation;
  final benefics = {'Jupiter', 'Venus', 'Moon', 'Mercury'};

  final result = <PlanetStrength>[];
  for (final planet in strengthPlanets) {
    final p = kundali.planets.firstWhere((x) => x.planet == planet);
    final debilitation = (_deepExaltation[planet]! + 180) % 360;
    final uchcha = _arc(p.longitude, debilitation) / 3;

    final sign = zodiacSignIndex(p.sign);
    final lord = DetectYogas.signLords[sign];
    final dignity = lord == planet
        ? 30.0
        : _friends[planet]!.contains(lord)
        ? 15.0
        : _enemies[planet]!.contains(lord)
        ? 3.75
        : 7.5;

    final dig =
        (180 - _arc(p.longitude, ascendant + _digPoint[planet]!)) / 3;

    final paksha = benefics.contains(planet)
        ? moonLight / 3
        : (180 - moonLight) / 3;

    final chesta = planet == 'Sun' || planet == 'Moon'
        ? 0.0
        : p.retrograde
        ? 60.0
        : 30.0;

    result.add(
      PlanetStrength(
        planet: planet,
        uchcha: uchcha,
        dignity: dignity,
        dig: dig,
        naisargika: _naisargika[planet]!,
        paksha: planet == 'Moon' ? paksha * 2 : paksha,
        chesta: chesta,
      ),
    );
  }
  result.sort((a, b) => b.total.compareTo(a.total));
  return result;
}
