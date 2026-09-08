import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_segment.dart';
import 'package:rv_astro_vastu/features/vastu/domain/usecases/calculate_vastu_entry_pada.dart';

void main() {
  const calculator = CalculateVastuEntryPada();

  group('CalculateVastuEntryPada', () {
    test('maps the beginning of a west wall to W1', () {
      final result = calculator(
        wallStart: VastuEntrySegment.w1,
        normalizedPosition: 0.0,
      );

      expect(result, VastuEntrySegment.w1);
    });

    test('maps the middle of each pada correctly on the west wall', () {
      const expected = <VastuEntrySegment>[
        VastuEntrySegment.w1,
        VastuEntrySegment.w2,
        VastuEntrySegment.w3,
        VastuEntrySegment.w4,
        VastuEntrySegment.w5,
        VastuEntrySegment.w6,
        VastuEntrySegment.w7,
        VastuEntrySegment.w8,
      ];

      for (var index = 0; index < expected.length; index++) {
        final position = (index + 0.5) / 8;

        final result = calculator(
          wallStart: VastuEntrySegment.w1,
          normalizedPosition: position,
        );

        expect(result, expected[index]);
      }
    });

    test('assigns exact pada boundaries to the next pada', () {
      expect(
        calculator(wallStart: VastuEntrySegment.w1, normalizedPosition: 0.125),
        VastuEntrySegment.w2,
      );

      expect(
        calculator(wallStart: VastuEntrySegment.w1, normalizedPosition: 0.25),
        VastuEntrySegment.w3,
      );

      expect(
        calculator(wallStart: VastuEntrySegment.w1, normalizedPosition: 0.375),
        VastuEntrySegment.w4,
      );

      expect(
        calculator(wallStart: VastuEntrySegment.w1, normalizedPosition: 0.5),
        VastuEntrySegment.w5,
      );

      expect(
        calculator(wallStart: VastuEntrySegment.w1, normalizedPosition: 0.625),
        VastuEntrySegment.w6,
      );

      expect(
        calculator(wallStart: VastuEntrySegment.w1, normalizedPosition: 0.75),
        VastuEntrySegment.w7,
      );

      expect(
        calculator(wallStart: VastuEntrySegment.w1, normalizedPosition: 0.875),
        VastuEntrySegment.w8,
      );
    });

    test('maps the end of a wall to pada 8', () {
      expect(
        calculator(wallStart: VastuEntrySegment.w1, normalizedPosition: 1.0),
        VastuEntrySegment.w8,
      );
    });

    test('preserves the wall direction', () {
      expect(
        calculator(wallStart: VastuEntrySegment.n1, normalizedPosition: 0.5),
        VastuEntrySegment.n5,
      );

      expect(
        calculator(wallStart: VastuEntrySegment.e1, normalizedPosition: 0.5),
        VastuEntrySegment.e5,
      );

      expect(
        calculator(wallStart: VastuEntrySegment.s1, normalizedPosition: 0.5),
        VastuEntrySegment.s5,
      );

      expect(
        calculator(wallStart: VastuEntrySegment.w1, normalizedPosition: 0.5),
        VastuEntrySegment.w5,
      );
    });

    test('rejects a position below zero', () {
      expect(
        () => calculator(
          wallStart: VastuEntrySegment.w1,
          normalizedPosition: -0.001,
        ),
        throwsRangeError,
      );
    });

    test('rejects a position above one', () {
      expect(
        () => calculator(
          wallStart: VastuEntrySegment.w1,
          normalizedPosition: 1.001,
        ),
        throwsRangeError,
      );
    });

    test('rejects a diagonal direction', () {
      final diagonalLikeSegment = VastuEntrySegment.values.firstWhere(
        (segment) => segment.direction.name == 'northeast',
        orElse: () => VastuEntrySegment.w1,
      );

      expect(diagonalLikeSegment, VastuEntrySegment.w1);
    });
  });
}
