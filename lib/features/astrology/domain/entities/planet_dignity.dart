import '../../../dosha/domain/entities/zodiac_signs.dart';
import '../../../yogas/domain/usecases/detect_yogas.dart';

/// Classical sign strength of a planet. Rahu and Ketu have no agreed
/// dignities, so they are always [neutral].
enum PlanetDignity { exalted, debilitated, own, neutral }

/// Exaltation sign index (Aries = 0) for the seven classical planets.
const Map<String, int> _exaltation = {
  'Sun': 0,
  'Moon': 1,
  'Mars': 9,
  'Mercury': 5,
  'Jupiter': 3,
  'Venus': 11,
  'Saturn': 6,
};

/// [planet] is a name such as 'Sun' or 'SUN'; [sign] is a sign name such as
/// 'Aries'. Exaltation wins over own sign (Mercury in Virgo is exalted).
PlanetDignity planetDignity(String planet, String sign) {
  final name = planet.isEmpty
      ? planet
      : planet[0].toUpperCase() + planet.substring(1).toLowerCase();
  final index = zodiacSignIndex(sign);
  final exalted = _exaltation[name];
  if (index < 0 || exalted == null) return PlanetDignity.neutral;

  if (index == exalted) return PlanetDignity.exalted;
  if (index == (exalted + 6) % 12) return PlanetDignity.debilitated;
  if (DetectYogas.signLords[index] == name) return PlanetDignity.own;
  return PlanetDignity.neutral;
}
