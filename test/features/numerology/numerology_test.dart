import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/numerology/domain/numerology.dart';

void main() {
  test('reduce keeps single digits and folds larger numbers', () {
    expect(Numerology.reduce(7), 7);
    expect(Numerology.reduce(13), 4);
    expect(Numerology.reduce(29), 2); // 2+9=11 → 2
    expect(Numerology.reduce(1987), 7); // 25 → 7
    expect(Numerology.reduce(0), 0);
  });

  test('Chaldean name totals', () {
    expect(Numerology.nameTotal('Ritesh'), 2 + 1 + 4 + 5 + 3 + 5);
    expect(Numerology.nameTotal('ritesh vyas'), 20 + 6 + 1 + 1 + 3);
    expect(Numerology.nameTotal('रितेश'), isNull);
    expect(Numerology.nameTotal(''), isNull);
  });

  test('report for 13 Dec 1987', () {
    final report = const Numerology()(
      dateOfBirth: DateTime(1987, 12, 13),
      name: 'LV',
      year: 2026,
    );

    expect(report.mulank, 4); // 1+3
    // 1+3 + 1+2 + 1+9+8+7 = 32 → 5
    expect(report.bhagyank, 5);
    // L=3, V=6
    expect(report.nameCompound, 9);
    expect(report.nameNumber, 9);
    // 1+3 + 1+2 + 2+0+2+6 = 17 → 8
    expect(report.personalYear, 8);
    expect(Numerology.rulingPlanet[report.mulank], 'Rahu');
  });

  test('names without Latin letters have no name number', () {
    final report = const Numerology()(
      dateOfBirth: DateTime(2000, 1, 1),
      name: 'रितेश',
      year: 2026,
    );
    expect(report.nameNumber, isNull);
    expect(report.mulank, 1);
  });
}
