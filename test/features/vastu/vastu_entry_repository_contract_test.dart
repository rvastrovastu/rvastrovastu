import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/vastu/data/repositories/local_vastu_entry_repository.dart';
import 'package:rv_astro_vastu/features/vastu/data/repositories/local_vastu_entry_deity_repository.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_assessment.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_direction.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_segment.dart';

void main() {
  const repository = LocalVastuEntryRepository();

  group('LocalVastuEntryRepository contract', () {
    test('exposes every cardinal entrance pada', () {
      final cardinal = VastuEntrySegment.values.where((s) => s.isCardinal);

      expect(repository.supportedSegments.toSet(), equals(cardinal.toSet()));
    });

    test('every supported segment has an assessment', () {
      for (final segment in repository.supportedSegments) {
        final assessment = repository.getAssessment(segment);

        expect(assessment.segment, equals(segment));
        expect(assessment.deityKey, isNotEmpty);
        expect(assessment.summaryKey, isNotEmpty);
      }
    });

    test('summary keys follow the segment code', () {
      for (final segment in repository.supportedSegments) {
        final assessment = repository.getAssessment(segment);

        if (segment == VastuEntrySegment.w4 || segment == VastuEntrySegment.w5) {
          continue; // these two keep their original names
        }
        expect(
          assessment.summaryKey,
          equals('vastu${segment.code}Summary'),
          reason: '${segment.code} summary key',
        );
      }
    });

    test('assessment deity mappings match the canonical deity repository', () {
      const deityRepository = LocalVastuEntryDeityRepository();

      for (final segment in repository.supportedSegments) {
        final assessment = repository.getAssessment(segment);
        final deity = deityRepository.getDeity(segment);

        expect(
          assessment.deityKey,
          equals(deity.deityKey),
          reason:
              '${segment.code} assessment deity must match canonical deity mapping',
        );
      }
    });

    test('every wall has eight padas', () {
      for (final direction in const [
        VastuEntryDirection.north,
        VastuEntryDirection.east,
        VastuEntryDirection.south,
        VastuEntryDirection.west,
      ]) {
        final padas = repository.supportedSegments
            .where((s) => s.direction == direction)
            .toList();

        expect(padas, hasLength(8), reason: direction.name);
      }
    });

    test('every assessment uses a known level', () {
      for (final segment in repository.supportedSegments) {
        final assessment = repository.getAssessment(segment);

        expect(
          VastuAssessmentLevel.values,
          contains(assessment.level),
          reason: segment.code,
        );
      }
    });
  });
}
