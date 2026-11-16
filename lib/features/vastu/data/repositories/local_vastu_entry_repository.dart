import '../../domain/entities/vastu_entry_assessment.dart';
import '../../domain/entities/vastu_entry_segment.dart';
import '../../domain/repositories/vastu_entry_repository.dart';

class LocalVastuEntryRepository implements VastuEntryRepository {
  const LocalVastuEntryRepository();

  static const _assessments = <VastuEntrySegment, VastuEntryAssessment>{
    VastuEntrySegment.n1: VastuEntryAssessment(
      segment: VastuEntrySegment.n1,
      level: VastuAssessmentLevel.challenging,
      deityKey: 'vastuRoga',
      summaryKey: 'vastuN1Summary',
    ),
    VastuEntrySegment.n2: VastuEntryAssessment(
      segment: VastuEntrySegment.n2,
      level: VastuAssessmentLevel.challenging,
      deityKey: 'vastuNaga',
      summaryKey: 'vastuN2Summary',
    ),
    VastuEntrySegment.n3: VastuEntryAssessment(
      segment: VastuEntrySegment.n3,
      level: VastuAssessmentLevel.favorable,
      deityKey: 'vastuMukhya',
      summaryKey: 'vastuN3Summary',
    ),
    VastuEntrySegment.n4: VastuEntryAssessment(
      segment: VastuEntrySegment.n4,
      level: VastuAssessmentLevel.neutral,
      deityKey: 'vastuBhallata',
      summaryKey: 'vastuN4Summary',
    ),
    VastuEntrySegment.n5: VastuEntryAssessment(
      segment: VastuEntrySegment.n5,
      level: VastuAssessmentLevel.favorable,
      deityKey: 'vastuSoma',
      summaryKey: 'vastuN5Summary',
    ),
    VastuEntrySegment.n6: VastuEntryAssessment(
      segment: VastuEntrySegment.n6,
      level: VastuAssessmentLevel.challenging,
      deityKey: 'vastuBhujaga',
      summaryKey: 'vastuN6Summary',
    ),
    VastuEntrySegment.n7: VastuEntryAssessment(
      segment: VastuEntrySegment.n7,
      level: VastuAssessmentLevel.favorable,
      deityKey: 'vastuAditi',
      summaryKey: 'vastuN7Summary',
    ),
    VastuEntrySegment.n8: VastuEntryAssessment(
      segment: VastuEntrySegment.n8,
      level: VastuAssessmentLevel.challenging,
      deityKey: 'vastuDiti',
      summaryKey: 'vastuN8Summary',
    ),
    VastuEntrySegment.e1: VastuEntryAssessment(
      segment: VastuEntrySegment.e1,
      level: VastuAssessmentLevel.neutral,
      deityKey: 'vastuShikhi',
      summaryKey: 'vastuE1Summary',
    ),
    VastuEntrySegment.e2: VastuEntryAssessment(
      segment: VastuEntrySegment.e2,
      level: VastuAssessmentLevel.favorable,
      deityKey: 'vastuParjanya',
      summaryKey: 'vastuE2Summary',
    ),
    VastuEntrySegment.e3: VastuEntryAssessment(
      segment: VastuEntrySegment.e3,
      level: VastuAssessmentLevel.favorable,
      deityKey: 'vastuJayanta',
      summaryKey: 'vastuE3Summary',
    ),
    VastuEntrySegment.e4: VastuEntryAssessment(
      segment: VastuEntrySegment.e4,
      level: VastuAssessmentLevel.favorable,
      deityKey: 'vastuIndra',
      summaryKey: 'vastuE4Summary',
    ),
    VastuEntrySegment.e5: VastuEntryAssessment(
      segment: VastuEntrySegment.e5,
      level: VastuAssessmentLevel.favorable,
      deityKey: 'vastuSurya',
      summaryKey: 'vastuE5Summary',
    ),
    VastuEntrySegment.e6: VastuEntryAssessment(
      segment: VastuEntrySegment.e6,
      level: VastuAssessmentLevel.favorable,
      deityKey: 'vastuSatya',
      summaryKey: 'vastuE6Summary',
    ),
    VastuEntrySegment.e7: VastuEntryAssessment(
      segment: VastuEntrySegment.e7,
      level: VastuAssessmentLevel.neutral,
      deityKey: 'vastuBhrisha',
      summaryKey: 'vastuE7Summary',
    ),
    VastuEntrySegment.e8: VastuEntryAssessment(
      segment: VastuEntrySegment.e8,
      level: VastuAssessmentLevel.neutral,
      deityKey: 'vastuAkasha',
      summaryKey: 'vastuE8Summary',
    ),
    VastuEntrySegment.s1: VastuEntryAssessment(
      segment: VastuEntrySegment.s1,
      level: VastuAssessmentLevel.neutral,
      deityKey: 'vastuAnila',
      summaryKey: 'vastuS1Summary',
    ),
    VastuEntrySegment.s2: VastuEntryAssessment(
      segment: VastuEntrySegment.s2,
      level: VastuAssessmentLevel.favorable,
      deityKey: 'vastuPusha',
      summaryKey: 'vastuS2Summary',
    ),
    VastuEntrySegment.s3: VastuEntryAssessment(
      segment: VastuEntrySegment.s3,
      level: VastuAssessmentLevel.neutral,
      deityKey: 'vastuVitatha',
      summaryKey: 'vastuS3Summary',
    ),
    VastuEntrySegment.s4: VastuEntryAssessment(
      segment: VastuEntrySegment.s4,
      level: VastuAssessmentLevel.neutral,
      deityKey: 'vastuGrihakshata',
      summaryKey: 'vastuS4Summary',
    ),
    VastuEntrySegment.s5: VastuEntryAssessment(
      segment: VastuEntrySegment.s5,
      level: VastuAssessmentLevel.challenging,
      deityKey: 'vastuYama',
      summaryKey: 'vastuS5Summary',
    ),
    VastuEntrySegment.s6: VastuEntryAssessment(
      segment: VastuEntrySegment.s6,
      level: VastuAssessmentLevel.neutral,
      deityKey: 'vastuGandharva',
      summaryKey: 'vastuS6Summary',
    ),
    VastuEntrySegment.s7: VastuEntryAssessment(
      segment: VastuEntrySegment.s7,
      level: VastuAssessmentLevel.neutral,
      deityKey: 'vastuBhringaraja',
      summaryKey: 'vastuS7Summary',
    ),
    VastuEntrySegment.s8: VastuEntryAssessment(
      segment: VastuEntrySegment.s8,
      level: VastuAssessmentLevel.neutral,
      deityKey: 'vastuMriga',
      summaryKey: 'vastuS8Summary',
    ),
    VastuEntrySegment.w1: VastuEntryAssessment(
      segment: VastuEntrySegment.w1,
      level: VastuAssessmentLevel.favorable,
      deityKey: 'vastuPitra',
      summaryKey: 'vastuW1Summary',
    ),
    VastuEntrySegment.w2: VastuEntryAssessment(
      segment: VastuEntrySegment.w2,
      level: VastuAssessmentLevel.neutral,
      deityKey: 'vastuDauvarika',
      summaryKey: 'vastuW2Summary',
    ),
    VastuEntrySegment.w3: VastuEntryAssessment(
      segment: VastuEntrySegment.w3,
      level: VastuAssessmentLevel.neutral,
      deityKey: 'vastuSugriva',
      summaryKey: 'vastuW3Summary',
    ),
    VastuEntrySegment.w4: VastuEntryAssessment(
      segment: VastuEntrySegment.w4,
      level: VastuAssessmentLevel.favorable,
      deityKey: 'vastuPushpadanta',
      summaryKey: 'vastuW4Summary',
    ),
    VastuEntrySegment.w5: VastuEntryAssessment(
      segment: VastuEntrySegment.w5,
      level: VastuAssessmentLevel.favorable,
      deityKey: 'vastuVaruna',
      summaryKey: 'vastuW5Summary',
    ),
    VastuEntrySegment.w6: VastuEntryAssessment(
      segment: VastuEntrySegment.w6,
      level: VastuAssessmentLevel.challenging,
      deityKey: 'vastuAsura',
      summaryKey: 'vastuW6Summary',
    ),
    VastuEntrySegment.w7: VastuEntryAssessment(
      segment: VastuEntrySegment.w7,
      level: VastuAssessmentLevel.challenging,
      deityKey: 'vastuShosha',
      summaryKey: 'vastuW7Summary',
    ),
    VastuEntrySegment.w8: VastuEntryAssessment(
      segment: VastuEntrySegment.w8,
      level: VastuAssessmentLevel.challenging,
      deityKey: 'vastuPapayakshma',
      summaryKey: 'vastuW8Summary',
    ),
  };

  @override
  List<VastuEntrySegment> get supportedSegments =>
      List.unmodifiable(_assessments.keys);

  @override
  VastuEntryAssessment getAssessment(VastuEntrySegment segment) {
    final assessment = _assessments[segment];

    if (assessment == null) {
      throw UnsupportedError(
        'Vastu entrance assessment is not yet defined for ${segment.code}.',
      );
    }

    return assessment;
  }
}
