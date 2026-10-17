import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/yogas/domain/entities/yoga.dart';
import 'package:rv_astro_vastu/features/yogas/domain/usecases/detect_yogas.dart';

import '../dosha/dosha_test_helpers.dart';

void main() {
  const detect = DetectYogas();

  Map<YogaId, YogaResult> run(String lagna, Map<String, String> signs) {
    final kundali = kundaliFrom(
      ascendant: inSign(lagna, 1),
      longitudes: {
        for (final entry in signs.entries) entry.key: inSign(entry.value),
      },
    );
    return {for (final y in detect(kundali)) y.id: y};
  }

  test('real chart: 13 Dec 1987, 00:42, Delhi (Virgo Lagna)', () {
    final yogas = run('Virgo', {
      'Sun': 'Scorpio',
      'Moon': 'Leo',
      'Mars': 'Libra',
      'Mercury': 'Scorpio',
      'Jupiter': 'Pisces',
      'Venus': 'Sagittarius',
      'Saturn': 'Scorpio',
      'Rahu': 'Pisces',
    });

    expect(yogas.keys.toSet(), {
      YogaId.budhaditya,
      YogaId.hamsa, // Jupiter in Pisces, 7th from Virgo
      YogaId.rajYoga, // Mercury (1st/10th lord) with Saturn (5th lord)
      YogaId.kemadruma,
    });
    expect(yogas[YogaId.rajYoga]!.planets, ['Mercury', 'Saturn']);
    // Mercury and Saturn sit in a kendra from the Moon.
    expect(yogas[YogaId.kemadruma]!.cancelled, isTrue);
  });

  test('Gajakesari, Shasha and Yogakaraka', () {
    final yogas = run('Taurus', {
      'Sun': 'Gemini',
      'Moon': 'Aries',
      'Mars': 'Pisces',
      'Mercury': 'Gemini',
      'Jupiter': 'Cancer', // 4th from an Aries Moon
      'Venus': 'Taurus',
      'Saturn': 'Aquarius', // own sign, 10th from Taurus
      'Rahu': 'Leo',
    });

    expect(yogas.containsKey(YogaId.gajakesari), isTrue);
    expect(yogas.containsKey(YogaId.shasha), isTrue);
    // Saturn rules the 9th and 10th for Taurus.
    expect(yogas[YogaId.yogakaraka]!.planets, ['Saturn']);
    // Venus in Taurus is in its own sign in the 1st house.
    expect(yogas.containsKey(YogaId.malavya), isTrue);
    expect(yogas.containsKey(YogaId.budhaditya), isTrue);
  });

  test('Viparita Raj yoga and Dhana yoga', () {
    // Aries Lagna: 6th lord Mercury in Virgo (6th); 2nd lord Venus with
    // 9th lord Jupiter in Sagittarius.
    final yogas = run('Aries', {
      'Sun': 'Leo',
      'Moon': 'Libra',
      'Mars': 'Aries',
      'Mercury': 'Virgo',
      'Jupiter': 'Sagittarius',
      'Venus': 'Sagittarius',
      'Saturn': 'Taurus',
      'Rahu': 'Gemini',
    });

    expect(yogas[YogaId.viparitaRajYoga]!.planets, ['Mercury']);
    expect(yogas[YogaId.dhanaYoga]!.planets, ['Jupiter', 'Venus']);
    // Mars in Aries, 1st house.
    expect(yogas.containsKey(YogaId.ruchaka), isTrue);
  });

  test('Kemadruma without cancellation', () {
    // Moon in Cancer in the 3rd from Taurus; Mars–Saturn all away from the
    // 2nd, 12th and kendras of the Moon.
    final yogas = run('Taurus', {
      'Sun': 'Leo',
      'Moon': 'Cancer',
      'Mars': 'Virgo',
      'Mercury': 'Virgo',
      'Jupiter': 'Scorpio',
      'Venus': 'Virgo',
      'Saturn': 'Pisces',
      'Rahu': 'Gemini',
    });

    expect(yogas[YogaId.kemadruma]!.cancelled, isFalse);
    expect(YogaId.kemadruma.nature, YogaNature.challenging);
  });

  test('throws when a classical planet is missing', () {
    expect(
      () => run('Aries', {'Sun': 'Leo', 'Moon': 'Libra', 'Rahu': 'Aries'}),
      throwsArgumentError,
    );
  });
}
