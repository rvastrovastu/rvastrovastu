import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_direction.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_segment.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entrance_input.dart';
import 'package:rv_astro_vastu/features/vastu/presentation/providers/vastu_entry_provider.dart';

void main() {
  group('calculateVastuEntrySegmentProvider', () {
    test('provides the entrance segment calculator', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final calculator = container.read(calculateVastuEntrySegmentProvider);

      expect(calculator, isNotNull);
      expect(
        calculator(
          const VastuEntranceInput(
            direction: VastuEntryDirection.west,
            normalizedPosition: 0.5,
          ),
        ),
        VastuEntrySegment.w5,
      );
    });

    test('calculates W4 through the provider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final calculator = container.read(calculateVastuEntrySegmentProvider);

      expect(
        calculator(
          const VastuEntranceInput(
            direction: VastuEntryDirection.west,
            normalizedPosition: 0.4375,
          ),
        ),
        VastuEntrySegment.w4,
      );
    });

    test('calculates W5 through the provider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final calculator = container.read(calculateVastuEntrySegmentProvider);

      expect(
        calculator(
          const VastuEntranceInput(
            direction: VastuEntryDirection.west,
            normalizedPosition: 0.5625,
          ),
        ),
        VastuEntrySegment.w5,
      );
    });

    test('supports all cardinal directions through the provider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final calculator = container.read(calculateVastuEntrySegmentProvider);

      const cases = <VastuEntryDirection, VastuEntrySegment>{
        VastuEntryDirection.north: VastuEntrySegment.n5,
        VastuEntryDirection.east: VastuEntrySegment.e5,
        VastuEntryDirection.south: VastuEntrySegment.s5,
        VastuEntryDirection.west: VastuEntrySegment.w5,
      };

      for (final entry in cases.entries) {
        expect(
          calculator(
            VastuEntranceInput(direction: entry.key, normalizedPosition: 0.5),
          ),
          entry.value,
        );
      }
    });

    test('existing W4 assessment provider remains unchanged', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final assessment = container.read(
        vastuEntryAssessmentProvider(VastuEntrySegment.w4),
      );

      expect(assessment.segment, VastuEntrySegment.w4);
      expect(assessment.level.name, 'favorable');
      expect(assessment.deityKey, 'vastuPushpadanta');
    });

    test('existing W5 assessment provider remains unchanged', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final assessment = container.read(
        vastuEntryAssessmentProvider(VastuEntrySegment.w5),
      );

      expect(assessment.segment, VastuEntrySegment.w5);
      expect(assessment.level.name, 'favorable');
      expect(assessment.deityKey, 'vastuVaruna');
    });
  });
}
