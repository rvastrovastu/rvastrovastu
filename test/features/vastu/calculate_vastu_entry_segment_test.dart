import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_direction.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_segment.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entrance_input.dart';
import 'package:rv_astro_vastu/features/vastu/domain/usecases/calculate_vastu_entry_segment.dart';

void main() {
  const calculate = CalculateVastuEntrySegment();

  group('CalculateVastuEntrySegment', () {
    test('calculates W1 at the beginning of the west wall', () {
      const input = VastuEntranceInput(
        direction: VastuEntryDirection.west,
        normalizedPosition: 0.0,
      );

      expect(calculate(input), VastuEntrySegment.w1);
    });

    test('calculates W5 at the middle of the west wall', () {
      const input = VastuEntranceInput(
        direction: VastuEntryDirection.west,
        normalizedPosition: 0.5,
      );

      expect(calculate(input), VastuEntrySegment.w5);
    });

    test('calculates W8 at the end of the west wall', () {
      const input = VastuEntranceInput(
        direction: VastuEntryDirection.west,
        normalizedPosition: 1.0,
      );

      expect(calculate(input), VastuEntrySegment.w8);
    });

    test('calculates the middle pada on every cardinal wall', () {
      const cases = <VastuEntryDirection, VastuEntrySegment>{
        VastuEntryDirection.north: VastuEntrySegment.n5,
        VastuEntryDirection.east: VastuEntrySegment.e5,
        VastuEntryDirection.south: VastuEntrySegment.s5,
        VastuEntryDirection.west: VastuEntrySegment.w5,
      };

      for (final entry in cases.entries) {
        final input = VastuEntranceInput(
          direction: entry.key,
          normalizedPosition: 0.5,
        );

        expect(calculate(input), entry.value);
      }
    });

    test('preserves all eight padas on the west wall', () {
      for (var i = 0; i < 8; i++) {
        final input = VastuEntranceInput(
          direction: VastuEntryDirection.west,
          normalizedPosition: (i + 0.5) / 8,
        );

        expect(calculate(input), VastuEntrySegment.values[24 + i]);
      }
    });

    test('rejects diagonal entrance directions', () {
      const diagonalDirections = <VastuEntryDirection>[
        VastuEntryDirection.northeast,
        VastuEntryDirection.southeast,
        VastuEntryDirection.southwest,
        VastuEntryDirection.northwest,
      ];

      for (final direction in diagonalDirections) {
        final input = VastuEntranceInput(
          direction: direction,
          normalizedPosition: 0.5,
        );

        expect(() => calculate(input), throwsA(isA<ArgumentError>()));
      }
    });
  });
}
