import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/dosha/domain/usecases/check_pitra_grahan_dosha.dart';

import 'dosha_test_helpers.dart';

void main() {
  const check = CheckPitraGrahanDosha();

  (PitraDoshaResult, GrahanDoshaResult) run(
    String lagna,
    Map<String, String> signs,
  ) => check(
    kundaliFrom(
      ascendant: inSign(lagna, 1),
      longitudes: {
        for (final entry in signs.entries) entry.key: inSign(entry.value),
      },
    ),
  );

  const clear = {
    'Sun': 'Leo',
    'Moon': 'Cancer',
    'Mars': 'Aries',
    'Mercury': 'Virgo',
    'Jupiter': 'Sagittarius',
    'Venus': 'Libra',
    'Saturn': 'Capricorn',
    'Rahu': 'Gemini', // Ketu in Sagittarius
  };

  test('no doshas when the luminaries are away from the nodes', () {
    // Taurus Lagna: the 9th (Capricorn) holds only its own lord, Saturn.
    final (pitra, grahan) = run('Taurus', clear);
    expect(pitra.isPresent, isFalse);
    expect(grahan.isPresent, isFalse);
    expect(pitra.ninthLord, 'Saturn');
  });

  test('Sun with Rahu forms both Pitra and solar Grahan dosha', () {
    final (pitra, grahan) = run('Taurus', {...clear, 'Rahu': 'Leo'});
    expect(pitra.factors, contains(PitraFactor.sunWithRahu));
    expect(grahan.factors, [GrahanFactor.sunWithRahu]);
    expect(grahan.solar, isTrue);
    expect(grahan.lunar, isFalse);
  });

  test('Moon with Ketu forms a lunar Grahan dosha only', () {
    // Rahu in Capricorn puts Ketu in Cancer with the Moon.
    final (pitra, grahan) = run('Gemini', {...clear, 'Rahu': 'Capricorn'});
    expect(grahan.factors, [GrahanFactor.moonWithKetu]);
    expect(grahan.lunar, isTrue);
    // Rahu in Capricorn joins Saturn, but Saturn is the 9th lord for a
    // Gemini Lagna (Aquarius), so the 9th-lord factor applies.
    expect(pitra.ninthLord, 'Saturn');
    expect(pitra.factors, [PitraFactor.ninthLordWithNode]);
  });

  test('Rahu in the 9th and Sun with Saturn', () {
    // Aries Lagna: the 9th is Sagittarius.
    final (pitra, _) = run('Aries', {
      ...clear,
      'Saturn': 'Leo',
      'Rahu': 'Sagittarius',
    });
    expect(
      pitra.factors,
      containsAll([PitraFactor.sunWithSaturn, PitraFactor.rahuInNinth]),
    );
  });
}
