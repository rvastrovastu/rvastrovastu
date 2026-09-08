import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/vastu/data/repositories/local_vastu_entry_repository.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_segment.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_direction.dart';

void main() {
  const repository = LocalVastuEntryRepository();

  group('LocalVastuEntryRepository contract', () {
    test('exposes only explicitly supported entrance segments', () {
      expect(
        repository.supportedSegments,
        equals([VastuEntrySegment.w4, VastuEntrySegment.w5]),
      );
    });

    test('every supported segment has an assessment', () {
      for (final segment in repository.supportedSegments) {
        final assessment = repository.getAssessment(segment);

        expect(assessment.segment, equals(segment));
        expect(assessment.deityKey, isNotEmpty);
        expect(assessment.summaryKey, isNotEmpty);
      }
    });

    test('unsupported segments are not exposed as supported', () {
      expect(
        repository.supportedSegments,
        isNot(contains(VastuEntrySegment.w1)),
      );
      expect(
        repository.supportedSegments,
        isNot(contains(VastuEntrySegment.w8)),
      );
      expect(
        repository.supportedSegments,
        isNot(contains(VastuEntrySegment.n1)),
      );
      expect(
        repository.supportedSegments,
        isNot(contains(VastuEntrySegment.e1)),
      );
      expect(
        repository.supportedSegments,
        isNot(contains(VastuEntrySegment.s1)),
      );
    });

    test('supported segments are west-wall padas W4 and W5', () {
      for (final segment in repository.supportedSegments) {
        expect(segment.direction, VastuEntryDirection.west);
        expect(segment.pada, anyOf(4, 5));
      }
    });

    test('every unsupported cardinal pada rejects assessment lookup', () {
      final unsupportedSegments = VastuEntrySegment.values
          .where(
            (segment) =>
                segment.isCardinal &&
                !repository.supportedSegments.contains(segment),
          )
          .toList();

      expect(unsupportedSegments, hasLength(30));

      for (final segment in unsupportedSegments) {
        expect(
          () => repository.getAssessment(segment),
          throwsUnsupportedError,
          reason: '${segment.code} must not have an assessment yet',
        );
      }
    });
  });
}
