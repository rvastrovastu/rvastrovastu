import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/vastu/data/repositories/local_vastu_entry_repository.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_assessment.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_segment.dart';

void main() {
  const repository = LocalVastuEntryRepository();

  group('West entrance padas', () {
    test('W4 is Pushpadanta and favorable', () {
      final assessment = repository.getAssessment(VastuEntrySegment.w4);

      expect(assessment.segment, equals(VastuEntrySegment.w4));
      expect(assessment.segment.code, equals('W4'));
      expect(assessment.deityKey, equals('vastuPushpadanta'));
      expect(assessment.level, equals(VastuAssessmentLevel.favorable));
      expect(assessment.summaryKey, equals('vastuW4Summary'));
    });

    test('W5 is Varuna and favorable', () {
      final assessment = repository.getAssessment(VastuEntrySegment.w5);

      expect(assessment.segment, equals(VastuEntrySegment.w5));
      expect(assessment.segment.code, equals('W5'));
      expect(assessment.deityKey, equals('vastuVaruna'));
      expect(assessment.level, equals(VastuAssessmentLevel.favorable));
      expect(assessment.summaryKey, equals('vastuW5Summary'));
    });

    test('W4 and W5 are both west-wall entrances', () {
      expect(VastuEntrySegment.w4.direction.name, equals('west'));
      expect(VastuEntrySegment.w5.direction.name, equals('west'));
    });

    test('a previously unwritten west pada now has an assessment', () {
      final assessment = repository.getAssessment(VastuEntrySegment.w3);

      expect(assessment.segment, equals(VastuEntrySegment.w3));
      expect(assessment.summaryKey, equals('vastuW3Summary'));
    });
  });

  test('repository exposes all 32 cardinal entrance padas', () {
    final segments = repository.supportedSegments;

    expect(segments.length, equals(32));
    for (final segment in VastuEntrySegment.values.where((s) => s.isCardinal)) {
      expect(segments, contains(segment), reason: segment.code);
    }
  });

  test('every supported entrance has an assessment', () {
    for (final segment in repository.supportedSegments) {
      final assessment = repository.getAssessment(segment);

      expect(assessment.segment, equals(segment));
    }
  });

  test('supported entrance segments contain no duplicates', () {
    final segments = repository.supportedSegments;

    expect(segments.toSet().length, equals(segments.length));
  });
}
