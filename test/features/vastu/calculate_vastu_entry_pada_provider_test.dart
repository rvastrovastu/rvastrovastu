import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_segment.dart';
import 'package:rv_astro_vastu/features/vastu/presentation/providers/vastu_entry_provider.dart';

void main() {
  group('calculateVastuEntryPadaProvider', () {
    test('provides the Vastu pada calculator', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final calculator = container.read(calculateVastuEntryPadaProvider);

      expect(calculator, isNotNull);
      expect(
        calculator(wallStart: VastuEntrySegment.w1, normalizedPosition: 0.5),
        VastuEntrySegment.w5,
      );
    });

    test('provider preserves the existing W4 assessment flow', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final assessment = container.read(
        vastuEntryAssessmentProvider(VastuEntrySegment.w4),
      );

      expect(assessment.segment, VastuEntrySegment.w4);
      expect(assessment.level.name, 'favorable');
      expect(assessment.deityKey, 'vastuPushpadanta');
    });

    test('provider preserves the existing W5 assessment flow', () {
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
