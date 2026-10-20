import '../../domain/entities/vastu_entry_assessment.dart';
import '../../domain/entities/vastu_entry_segment.dart';
import '../../domain/repositories/vastu_entry_repository.dart';

class LocalVastuEntryRepository implements VastuEntryRepository {
  const LocalVastuEntryRepository();

  static const _assessments = <VastuEntrySegment, VastuEntryAssessment>{
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
