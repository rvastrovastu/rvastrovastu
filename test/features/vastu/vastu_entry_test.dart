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

    test('unsupported entrance pada fails explicitly', () {
      expect(
        () => repository.getAssessment(VastuEntrySegment.w3),
        throwsUnsupportedError,
      );
    });
  });

  test('repository exposes only implemented entrance assessments', () {
    expect(
      repository.supportedSegments,
      equals([VastuEntrySegment.w4, VastuEntrySegment.w5]),
    );
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
