import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_period.dart';
import 'package:rv_astro_vastu/features/dasha/domain/usecases/generate_dasha_insight.dart';

void main() {
  final generator = GenerateDashaInsight();

  DashaPeriod period(DashaPlanet planet, {int level = 1}) {
    return DashaPeriod(
      planet: planet,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2027, 1, 1),
      level: level,
    );
  }

  test('returns unavailable insight when Mahadasha is null', () {
    final result = generator.call(mahadasha: null, antardasha: null);

    expect(result.hasCurrentPeriod, isFalse);
    expect(result.mahadasha, isNull);
    expect(result.antardasha, isNull);
    expect(result.focus, contains('not available'));
    expect(result.career, contains('birth profile'));
  });

  test('returns current Mahadasha and Antardasha', () {
    final mahadasha = period(DashaPlanet.mercury);
    final antardasha = period(DashaPlanet.venus, level: 2);

    final result = generator.call(mahadasha: mahadasha, antardasha: antardasha);

    expect(result.hasCurrentPeriod, isTrue);
    expect(result.mahadasha, same(mahadasha));
    expect(result.antardasha, same(antardasha));
    expect(result.focus, contains('Mercury Mahadasha'));
    expect(result.focus, contains('Venus Antardasha'));
  });

  test('generates Mercury career insight', () {
    final result = generator.call(
      mahadasha: period(DashaPlanet.mercury),
      antardasha: period(DashaPlanet.venus, level: 2),
    );

    expect(result.career, contains('Communication'));
    expect(result.finance, contains('Planning'));
    expect(result.relationships, contains('communication'));
  });

  test('generates Saturn career and finance discipline insight', () {
    final result = generator.call(
      mahadasha: period(DashaPlanet.saturn),
      antardasha: period(DashaPlanet.mercury, level: 2),
    );

    expect(result.career, contains('Discipline'));
    expect(result.finance, contains('discipline'));
    expect(result.relationships, contains('Consistency'));
  });

  test('generates Jupiter growth insight', () {
    final result = generator.call(
      mahadasha: period(DashaPlanet.jupiter),
      antardasha: period(DashaPlanet.moon, level: 2),
    );

    expect(result.career, contains('Growth'));
    expect(result.finance, contains('growth'));
    expect(result.relationships, contains('wisdom'));
  });

  test('ignores Antardasha outside Mahadasha bounds', () {
    final mahadasha = period(DashaPlanet.mercury);
    final mismatchedAntardasha = period(DashaPlanet.venus).copyWith(
      startDate: DateTime(2027, 1, 1),
      endDate: DateTime(2028, 1, 1),
      level: 2,
    );

    final result = generator.call(
      mahadasha: mahadasha,
      antardasha: mismatchedAntardasha,
    );

    expect(result.mahadasha, same(mahadasha));
    expect(result.antardasha, isNull);
    expect(result.focus, contains('Mercury Mahadasha'));
    expect(result.focus, isNot(contains('Venus Antardasha')));
  });

  test('supports every Vimshottari planet', () {
    for (final planet in DashaPlanet.values) {
      final result = generator.call(
        mahadasha: period(planet),
        antardasha: null,
      );

      expect(result.hasCurrentPeriod, isTrue);
      expect(result.career, isNotEmpty);
      expect(result.finance, isNotEmpty);
      expect(result.relationships, isNotEmpty);
      expect(result.focus, contains(planet.name));
    }
  });
}
