import '../../../astrology/domain/entities/kundali.dart';
import '../../../yogas/domain/usecases/detect_yogas.dart';
import '../entities/zodiac_signs.dart';

/// What forms a Pitra dosha in a chart, as commonly read.
enum PitraFactor {
  /// The Sun (father, ancestors) with Rahu in one sign.
  sunWithRahu,

  /// The Sun with Ketu in one sign.
  sunWithKetu,

  /// The Sun with Saturn in one sign.
  sunWithSaturn,

  /// Rahu in the 9th house (the house of father and ancestors).
  rahuInNinth,

  /// Ketu in the 9th house.
  ketuInNinth,

  /// The 9th lord joined by Rahu or Ketu.
  ninthLordWithNode,
}

/// What forms a Grahan (eclipse) dosha: a luminary with a node.
enum GrahanFactor { sunWithRahu, sunWithKetu, moonWithRahu, moonWithKetu }

class PitraDoshaResult {
  final List<PitraFactor> factors;

  /// The 9th lord, named in the [PitraFactor.ninthLordWithNode] line.
  final String ninthLord;

  const PitraDoshaResult({required this.factors, required this.ninthLord});

  bool get isPresent => factors.isNotEmpty;
}

class GrahanDoshaResult {
  final List<GrahanFactor> factors;

  const GrahanDoshaResult({required this.factors});

  bool get isPresent => factors.isNotEmpty;

  /// A Surya (solar) Grahan dosha: the Sun with a node.
  bool get solar =>
      factors.contains(GrahanFactor.sunWithRahu) ||
      factors.contains(GrahanFactor.sunWithKetu);

  /// A Chandra (lunar) Grahan dosha: the Moon with a node.
  bool get lunar =>
      factors.contains(GrahanFactor.moonWithRahu) ||
      factors.contains(GrahanFactor.moonWithKetu);
}

/// Pitra and Grahan doshas, from whole-sign placements.
///
/// These are popular rather than strictly classical combinations; the app
/// shows the placements that form them so the reading stays transparent.
class CheckPitraGrahanDosha {
  const CheckPitraGrahanDosha();

  (PitraDoshaResult, GrahanDoshaResult) call(Kundali kundali) {
    final lagna = zodiacSignIndex(kundali.ascendant);
    if (lagna < 0) {
      throw ArgumentError('Unknown ascendant sign: "${kundali.ascendant}".');
    }
    final signs = <String, int>{
      for (final p in kundali.planets)
        if (zodiacSignIndex(p.sign) >= 0) p.planet: zodiacSignIndex(p.sign),
    };
    for (final name in const ['Sun', 'Moon', 'Saturn', 'Rahu']) {
      if (!signs.containsKey(name)) {
        throw ArgumentError('Kundali is missing $name.');
      }
    }
    // Ketu is always opposite Rahu.
    signs.putIfAbsent('Ketu', () => (signs['Rahu']! + 6) % 12);

    bool together(String a, String b) => signs[a] == signs[b];
    int houseOf(String planet) => houseFrom(lagna, signs[planet]!);
    final ninthLord = DetectYogas.signLords[(lagna + 8) % 12];

    final pitra = <PitraFactor>[
      if (together('Sun', 'Rahu')) PitraFactor.sunWithRahu,
      if (together('Sun', 'Ketu')) PitraFactor.sunWithKetu,
      if (together('Sun', 'Saturn')) PitraFactor.sunWithSaturn,
      if (houseOf('Rahu') == 9) PitraFactor.rahuInNinth,
      if (houseOf('Ketu') == 9) PitraFactor.ketuInNinth,
      if (signs.containsKey(ninthLord) &&
          (together(ninthLord, 'Rahu') || together(ninthLord, 'Ketu')))
        PitraFactor.ninthLordWithNode,
    ];

    final grahan = <GrahanFactor>[
      if (together('Sun', 'Rahu')) GrahanFactor.sunWithRahu,
      if (together('Sun', 'Ketu')) GrahanFactor.sunWithKetu,
      if (together('Moon', 'Rahu')) GrahanFactor.moonWithRahu,
      if (together('Moon', 'Ketu')) GrahanFactor.moonWithKetu,
    ];

    return (
      PitraDoshaResult(factors: pitra, ninthLord: ninthLord),
      GrahanDoshaResult(factors: grahan),
    );
  }
}
