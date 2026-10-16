import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_birth_data.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_period.dart';
import 'package:rv_astro_vastu/features/dasha/domain/usecases/calculate_vimshottari_dasha.dart';
import 'package:rv_astro_vastu/features/dasha/domain/usecases/calculate_vimshottari_start.dart';

void main() {
  group('Vimshottari regression tests', () {
    final startCalculator = CalculateVimshottariStart();
    const expectedLords = [
      DashaPlanet.ketu,
      DashaPlanet.venus,
      DashaPlanet.sun,
      DashaPlanet.moon,
      DashaPlanet.mars,
      DashaPlanet.rahu,
      DashaPlanet.jupiter,
      DashaPlanet.saturn,
      DashaPlanet.mercury,
    ];

    test('each Nakshatra boundary selects the correct starting lord', () {
      for (var index = 0; index < 27; index++) {
        final longitude = index * CalculateVimshottariStart.nakshatraSpan;
        final result = startCalculator(
          birthData: DashaBirthData(
            birthDate: DateTime(2000, 1, 1),
            moonLongitude: longitude,
          ),
        );

        expect(result.nakshatraIndex, index, reason: 'Boundary $index');
        expect(
          result.planet,
          expectedLords[index % 9],
          reason: 'Boundary $index',
        );
        expect(result.balance, closeTo(1.0, 0.000001));
      }
    });

    test(
      'longitude just below a Nakshatra boundary stays in the previous Nakshatra',
      () {
        const epsilon = 1e-6;
        final result = startCalculator(
          birthData: DashaBirthData(
            birthDate: DateTime(2000, 1, 1),
            moonLongitude: CalculateVimshottariStart.nakshatraSpan - epsilon,
          ),
        );

        expect(result.nakshatraIndex, 0);
        expect(result.planet, DashaPlanet.ketu);
        expect(result.nakshatraProgress, lessThan(1.0));
        expect(result.balance, greaterThan(0.0));
      },
    );

    test(
      'longitude just above a Nakshatra boundary selects the next Nakshatra',
      () {
        const epsilon = 1e-6;
        final result = startCalculator(
          birthData: DashaBirthData(
            birthDate: DateTime(2000, 1, 1),
            moonLongitude: CalculateVimshottariStart.nakshatraSpan + epsilon,
          ),
        );

        expect(result.nakshatraIndex, 1);
        expect(result.planet, DashaPlanet.venus);
        expect(result.nakshatraProgress, greaterThan(0.0));
        expect(result.balance, lessThan(1.0));
      },
    );

    test('generated Mahadasha dates never run backwards near a boundary', () {
      const epsilon = 1e-6;
      final birthDate = DateTime(2000, 1, 31, 12, 30);
      final timeline = CalculateVimshottariDasha().call(
        birthData: DashaBirthData(
          birthDate: birthDate,
          moonLongitude: CalculateVimshottariStart.nakshatraSpan - epsilon,
        ),
      );

      expect(timeline.periods, isNotEmpty);

      for (final period in timeline.periods) {
        expect(
          period.endDate.isBefore(period.startDate),
          isFalse,
          reason: '${period.planet} must not end before it starts',
        );
      }

      for (var i = 0; i < timeline.periods.length - 1; i++) {
        expect(
          timeline.periods[i].endDate,
          timeline.periods[i + 1].startDate,
          reason: 'Mahadashas must remain contiguous at index $i',
        );
      }
    });

    test('midpoint of first Nakshatra leaves half the Ketu period', () {
      final result = startCalculator(
        birthData: DashaBirthData(
          birthDate: DateTime(2000, 1, 1),
          moonLongitude: CalculateVimshottariStart.nakshatraSpan / 2,
        ),
      );

      expect(result.planet, DashaPlanet.ketu);
      expect(result.nakshatraProgress, closeTo(0.5, 0.000001));
      expect(result.balance, closeTo(0.5, 0.000001));
    });

    test('rejects non-finite Moon longitudes', () {
      for (final longitude in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => startCalculator(
            birthData: DashaBirthData(
              birthDate: DateTime(2000, 1, 1),
              moonLongitude: longitude,
            ),
          ),
          throwsArgumentError,
          reason: 'Longitude $longitude must be rejected',
        );
      }
    });

    test('normalizes finite longitudes outside the 0-to-360 range', () {
      final negative = startCalculator(
        birthData: DashaBirthData(
          birthDate: DateTime(2000, 1, 1),
          moonLongitude: -1,
        ),
      );
      final wrapped = startCalculator(
        birthData: DashaBirthData(
          birthDate: DateTime(2000, 1, 1),
          moonLongitude: 359,
        ),
      );

      expect(negative.nakshatraIndex, wrapped.nakshatraIndex);
      expect(negative.planet, wrapped.planet);
      expect(
        negative.nakshatraProgress,
        closeTo(wrapped.nakshatraProgress, 0.000001),
      );

      final aboveRange = startCalculator(
        birthData: DashaBirthData(
          birthDate: DateTime(2000, 1, 1),
          moonLongitude: 361,
        ),
      );
      final wrappedPositive = startCalculator(
        birthData: DashaBirthData(
          birthDate: DateTime(2000, 1, 1),
          moonLongitude: 1,
        ),
      );

      expect(aboveRange.nakshatraIndex, wrappedPositive.nakshatraIndex);
      expect(aboveRange.planet, wrappedPositive.planet);
      expect(
        aboveRange.nakshatraProgress,
        closeTo(wrappedPositive.nakshatraProgress, 0.000001),
      );
    });

    test('returns no subperiods for invalid parent date ranges', () {
      final calculator = CalculateVimshottariDasha();
      final start = DateTime(2024, 1, 1);

      for (final end in [start, DateTime(2023, 12, 31)]) {
        final invalidParent = DashaPeriod(
          planet: DashaPlanet.moon,
          startDate: start,
          endDate: end,
          level: 1,
        );

        expect(calculator.antardashas(invalidParent), isEmpty);
        expect(calculator.pratyantardashas(invalidParent), isEmpty);
      }
    });

    test('longitude 360 degrees normalizes to zero degrees', () {
      final result = startCalculator(
        birthData: DashaBirthData(
          birthDate: DateTime(2000, 1, 1),
          moonLongitude: 360,
        ),
      );

      expect(result.nakshatraIndex, 0);
      expect(result.planet, DashaPlanet.ketu);
      expect(result.balance, closeTo(1.0, 0.000001));
    });

    test('Antardashas follow the Vimshottari order and remain contiguous', () {
      final parent = DashaPeriod(
        planet: DashaPlanet.rahu,
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2038, 1, 1),
        level: 1,
      );

      final periods = CalculateVimshottariDasha().antardashas(parent);

      expect(periods.map((period) => period.planet).toList(), [
        DashaPlanet.rahu,
        DashaPlanet.jupiter,
        DashaPlanet.saturn,
        DashaPlanet.mercury,
        DashaPlanet.ketu,
        DashaPlanet.venus,
        DashaPlanet.sun,
        DashaPlanet.moon,
        DashaPlanet.mars,
      ]);
      expect(periods.first.startDate, parent.startDate);
      expect(periods.last.endDate, parent.endDate);

      for (var i = 0; i < periods.length - 1; i++) {
        expect(periods[i].endDate, periods[i + 1].startDate);
      }
    });

    test(
      'Pratyantardashas follow the Vimshottari order and remain contiguous',
      () {
        final parent = DashaPeriod(
          planet: DashaPlanet.moon,
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2025, 1, 1),
          level: 2,
        );

        final periods = CalculateVimshottariDasha().pratyantardashas(parent);

        expect(periods.map((period) => period.planet).toList(), [
          DashaPlanet.moon,
          DashaPlanet.mars,
          DashaPlanet.rahu,
          DashaPlanet.jupiter,
          DashaPlanet.saturn,
          DashaPlanet.mercury,
          DashaPlanet.ketu,
          DashaPlanet.venus,
          DashaPlanet.sun,
        ]);
        expect(periods.first.startDate, parent.startDate);
        expect(periods.last.endDate, parent.endDate);

        for (var i = 0; i < periods.length - 1; i++) {
          expect(periods[i].endDate, periods[i + 1].startDate);
        }
      },
    );
  });
}
