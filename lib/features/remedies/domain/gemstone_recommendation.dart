import '../../dosha/domain/entities/zodiac_signs.dart';
import '../../yogas/domain/usecases/detect_yogas.dart';

/// Why a stone is suggested, following the common Lagna-based method.
enum GemstoneRole {
  /// Lagna lord — the "life stone".
  life,

  /// 5th lord — the "lucky" (punya) stone.
  lucky,

  /// 9th lord — the "fortune" (bhagya) stone.
  fortune,
}

class GemstoneRecommendation {
  /// Planet name as used across the app ('Mercury', 'Venus', …).
  final String planet;

  /// Every role this planet fills (a planet can rule both the 5th and 9th).
  final List<GemstoneRole> roles;

  /// Houses this planet rules for the Lagna.
  final List<int> housesRuled;

  const GemstoneRecommendation({
    required this.planet,
    required this.roles,
    required this.housesRuled,
  });

  /// A 5th or 9th lord that also rules the 6th, 8th or 12th; many
  /// astrologers advise a consultation before wearing its stone. The Lagna
  /// lord is traditionally auspicious whatever else it rules.
  bool get needsCaution =>
      !roles.contains(GemstoneRole.life) &&
      housesRuled.any((h) => h == 6 || h == 8 || h == 12);
}

/// Life, lucky and fortune stones from the Lagna (Rahu and Ketu rule no
/// sign, so they never appear here).
List<GemstoneRecommendation> recommendGemstones(String lagnaSign) {
  final lagna = zodiacSignIndex(lagnaSign);
  if (lagna < 0) throw ArgumentError('Unknown Lagna sign: "$lagnaSign".');

  String lordOf(int house) => DetectYogas.signLords[(lagna + house - 1) % 12];

  final roles = <String, List<GemstoneRole>>{};
  for (final (house, role) in const [
    (1, GemstoneRole.life),
    (5, GemstoneRole.lucky),
    (9, GemstoneRole.fortune),
  ]) {
    roles.putIfAbsent(lordOf(house), () => []).add(role);
  }

  return [
    for (final entry in roles.entries)
      GemstoneRecommendation(
        planet: entry.key,
        roles: entry.value,
        housesRuled: [
          for (var h = 1; h <= 12; h++)
            if (lordOf(h) == entry.key) h,
        ],
      ),
  ];
}
