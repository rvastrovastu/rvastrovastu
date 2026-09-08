import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_direction.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entrance_input.dart';

void main() {
  group('VastuEntranceInput', () {
    test('stores cardinal wall direction and normalized position', () {
      const input = VastuEntranceInput(
        direction: VastuEntryDirection.west,
        normalizedPosition: 0.5,
      );

      expect(input.direction, VastuEntryDirection.west);
      expect(input.normalizedPosition, 0.5);
    });

    test('accepts the lower boundary', () {
      const input = VastuEntranceInput(
        direction: VastuEntryDirection.north,
        normalizedPosition: 0.0,
      );

      expect(input.normalizedPosition, 0.0);
    });

    test('accepts the upper boundary', () {
      const input = VastuEntranceInput(
        direction: VastuEntryDirection.east,
        normalizedPosition: 1.0,
      );

      expect(input.normalizedPosition, 1.0);
    });

    test('rejects a position below zero', () {
      expect(
        () => VastuEntranceInput(
          direction: VastuEntryDirection.south,
          normalizedPosition: -0.01,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a position above one', () {
      expect(
        () => VastuEntranceInput(
          direction: VastuEntryDirection.west,
          normalizedPosition: 1.01,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('supports all cardinal directions', () {
      for (final direction in <VastuEntryDirection>[
        VastuEntryDirection.north,
        VastuEntryDirection.east,
        VastuEntryDirection.south,
        VastuEntryDirection.west,
      ]) {
        final input = VastuEntranceInput(
          direction: direction,
          normalizedPosition: 0.5,
        );

        expect(input.direction, direction);
        expect(input.normalizedPosition, 0.5);
      }
    });

    test('direction enum still retains diagonal directions for future use', () {
      expect(
        VastuEntryDirection.values,
        containsAll(<VastuEntryDirection>[
          VastuEntryDirection.northeast,
          VastuEntryDirection.southeast,
          VastuEntryDirection.southwest,
          VastuEntryDirection.northwest,
        ]),
      );
    });
  });
}
