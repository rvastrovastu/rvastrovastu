import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/numerology/domain/numerology.dart';
import 'package:rv_astro_vastu/features/numerology/domain/numerology_forecast.dart';

void main() {
  test('relation is the same in both directions for every pair', () {
    for (var a = 1; a <= 9; a++) {
      for (var b = 1; b <= 9; b++) {
        expect(
          NumerologyForecast.relation(a, b),
          NumerologyForecast.relation(b, a),
          reason: 'pair $a and $b',
        );
      }
    }
  });

  test('known pairs from the planetary table', () {
    expect(NumerologyForecast.relation(2, 2), NumberRelation.same);
    expect(NumerologyForecast.relation(2, 5), NumberRelation.neutral); // Moon–Mercury: friend one way, enemy the other
    expect(NumerologyForecast.relation(1, 2), NumberRelation.friend); // Sun–Moon
    expect(NumerologyForecast.relation(8, 9), NumberRelation.challenging); // Saturn–Mars
    expect(NumerologyForecast.relation(9, 8), NumberRelation.challenging);
    expect(NumerologyForecast.relation(9, 3), NumberRelation.friend); // Mars–Jupiter
  });

  test('personal year, month and day follow the standard chain', () {
    // Birth 13 Dec 1987, year 2026: 1+3 + 1+2 + 2+0+2+6 = 17 → 8
    final py = Numerology.reduce(4 + 3 + 10);
    expect(py, 8);
    final pm = NumerologyForecast.personalMonth(py, 11); // 8 + 11 = 19 → 1
    expect(pm, 1);
    expect(NumerologyForecast.personalDay(pm, 5), 6); // 1 + 5
  });

  test('lucky dates use the day of month reduced to 1–9', () {
    final dates = NumerologyForecast.luckyDates(
      mulank: 2,
      from: DateTime(2026, 11, 5),
      days: 10,
      take: 10,
    );
    // Nov 5 → 5 neutral; 6, 7, 8 challenging; Nov 9 → 9 friend (Mars);
    // Nov 10 → 1 friend (Sun); Nov 11 → 2 same; Nov 12 → 3 friend (Jupiter);
    // Nov 13 → 4 challenging (Rahu); Nov 14 → 5 neutral.
    expect(dates.map((d) => d.$1.day).toList(), [9, 10, 11, 12]);
    expect(dates[0].$2, NumberRelation.friend);
    expect(dates[1].$2, NumberRelation.friend);
    expect(dates[2].$2, NumberRelation.same);
    expect(dates[3].$2, NumberRelation.friend);
  });
}
