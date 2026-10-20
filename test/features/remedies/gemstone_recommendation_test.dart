import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/remedies/domain/gemstone_recommendation.dart';

void main() {
  test('Virgo Lagna: Mercury, Saturn and Venus', () {
    final stones = recommendGemstones('Virgo');

    expect(stones.map((s) => s.planet), ['Mercury', 'Saturn', 'Venus']);

    expect(stones[0].roles, [GemstoneRole.life]);
    expect(stones[0].housesRuled, [1, 10]);
    expect(stones[0].needsCaution, isFalse);

    // Saturn rules the 5th (Capricorn) and the 6th (Aquarius).
    expect(stones[1].roles, [GemstoneRole.lucky]);
    expect(stones[1].housesRuled, [5, 6]);
    expect(stones[1].needsCaution, isTrue);

    // Venus rules the 2nd (Libra) and the 9th (Taurus).
    expect(stones[2].roles, [GemstoneRole.fortune]);
    expect(stones[2].housesRuled, [2, 9]);
    expect(stones[2].needsCaution, isFalse);
  });

  test('the Lagna lord never carries a caution', () {
    // Aries: Mars rules the 1st and the 8th.
    final aries = recommendGemstones('Aries');
    expect(aries.map((s) => s.planet), ['Mars', 'Sun', 'Jupiter']);
    expect(aries[0].housesRuled, [1, 8]);
    expect(aries[0].needsCaution, isFalse);
    // Jupiter (9th) also rules the 12th.
    expect(aries[2].needsCaution, isTrue);
  });

  test('each Lagna gives three different planets', () {
    const signs = [
      'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
      'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces',
    ];
    for (final sign in signs) {
      final stones = recommendGemstones(sign);
      expect(stones, hasLength(3), reason: sign);
      expect(
        stones.map((s) => s.roles.single),
        GemstoneRole.values,
        reason: sign,
      );
    }
  });

  test('Pisces Lagna: Jupiter, Moon and Mars, none flagged', () {
    final stones = recommendGemstones('Pisces');
    expect(stones.map((s) => s.planet), ['Jupiter', 'Moon', 'Mars']);
    expect(stones.any((s) => s.needsCaution), isFalse);
  });

  test('rejects an unknown sign', () {
    expect(() => recommendGemstones('Ophiuchus'), throwsArgumentError);
  });
}
