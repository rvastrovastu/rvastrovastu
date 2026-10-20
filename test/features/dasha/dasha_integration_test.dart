import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_birth_data.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_period.dart';
import 'package:rv_astro_vastu/features/dasha/domain/usecases/calculate_current_dasha.dart';
import 'package:rv_astro_vastu/features/dasha/domain/usecases/calculate_vimshottari_dasha.dart';
import 'package:rv_astro_vastu/features/dasha/domain/usecases/calculate_vimshottari_start.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_timeline.dart';

void main() {
  test('current Mahadasha changes at the exact transition boundary', () {
    final first = DashaPeriod(
      planet: DashaPlanet.sun,
      startDate: DateTime(2020, 1, 1),
      endDate: DateTime(2026, 1, 1),
      level: 1,
    );

    final second = DashaPeriod(
      planet: DashaPlanet.moon,
      startDate: first.endDate,
      endDate: DateTime(2036, 1, 1),
      level: 1,
    );

    final timeline = DashaTimeline(periods: [first, second]);

    final result = CalculateCurrentDasha().call(
      timeline: timeline,
      date: first.endDate,
    );

    expect(result.mahadasha?.planet, DashaPlanet.moon);
  });

  test('calculates Dasha timeline from Moon longitude', () {
    final birthData = DashaBirthData(
      birthDate: DateTime(1983, 1, 3, 6),
      moonLongitude: 120.0,
    );

    final timeline = CalculateVimshottariDasha().call(birthData: birthData);

    expect(timeline.periods, isNotEmpty);
    expect(timeline.periods.length, 9);

    for (var i = 0; i < timeline.periods.length - 1; i++) {
      expect(
        timeline.periods[i].endDate,
        equals(timeline.periods[i + 1].startDate),
      );
    }
  });

  test('current Dasha can be resolved from timeline', () {
    final birthData = DashaBirthData(
      birthDate: DateTime(1983, 1, 3, 6),
      moonLongitude: 120.0,
    );

    final timeline = CalculateVimshottariDasha().call(birthData: birthData);

    final result = CalculateCurrentDasha().call(timeline: timeline);

    expect(result.mahadasha, isNotNull);
  });

  test(
    'Vimshottari Dasha uses Moon longitude to determine starting Mahadasha',
    () {
      final birthData = DashaBirthData(
        birthDate: DateTime(1983, 1, 3, 6),
        moonLongitude: 0.0,
      );

      final start = CalculateVimshottariStart().call(birthData: birthData);

      expect(start.nakshatraIndex, equals(0));
      expect(start.planet, equals(DashaPlanet.ketu));
      expect(start.balance, closeTo(1.0, 0.000001));
    },
  );

  test('handles a leap-day birth date when adding whole Mahadasha years', () {
    final birthData = DashaBirthData(
      birthDate: DateTime(2000, 2, 29, 6, 30),
      moonLongitude: 0.0,
    );

    final timeline = CalculateVimshottariDasha().call(birthData: birthData);

    expect(timeline.periods.first.planet, DashaPlanet.ketu);
    expect(timeline.periods.first.startDate, DateTime(2000, 2, 29, 6, 30));
    expect(timeline.periods.first.endDate, DateTime(2007, 2, 28, 6, 30));
  });

  test('converts a half-balance Ketu Mahadasha to the expected date', () {
    final birthData = DashaBirthData(
      birthDate: DateTime(2000, 1, 1, 6),
      moonLongitude: CalculateVimshottariStart.nakshatraSpan / 2,
    );

    final timeline = CalculateVimshottariDasha().call(birthData: birthData);

    expect(timeline.periods.first.planet, DashaPlanet.ketu);
    expect(timeline.periods.first.endDate, DateTime(2003, 7, 3, 7));
  });

  test('Antardasha produces 9 nested periods inside a Mahadasha', () {
    final mahadasha = DashaPeriod(
      planet: DashaPlanet.sun,
      startDate: DateTime(2020, 1, 1),
      endDate: DateTime(2026, 1, 1),
      level: 1,
    );

    final periods = CalculateVimshottariDasha().antardashas(mahadasha);

    expect(periods, hasLength(9));

    expect(periods.first.planet, equals(DashaPlanet.sun));
    expect(periods.first.level, equals(2));

    expect(periods.first.startDate, equals(mahadasha.startDate));

    expect(periods.last.endDate, equals(mahadasha.endDate));

    for (var i = 0; i < periods.length - 1; i++) {
      expect(periods[i].endDate, equals(periods[i + 1].startDate));
    }
  });

  test('Pratyantardasha produces nested periods inside an Antardasha', () {
    final antardasha = DashaPeriod(
      planet: DashaPlanet.moon,
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2025, 1, 1),
      level: 2,
    );

    final periods = CalculateVimshottariDasha().pratyantardashas(antardasha);

    expect(periods, hasLength(9));

    expect(periods.first.planet, equals(DashaPlanet.moon));
    expect(periods.first.level, equals(3));

    expect(periods.first.startDate, equals(antardasha.startDate));

    expect(periods.last.endDate, equals(antardasha.endDate));

    for (var i = 0; i < periods.length - 1; i++) {
      expect(periods[i].endDate, equals(periods[i + 1].startDate));
    }
  });
}
