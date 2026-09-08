import '../entities/vastu_entry_assessment.dart';
import '../entities/vastu_entry_segment.dart';

abstract interface class VastuEntryRepository {
  List<VastuEntrySegment> get supportedSegments;

  VastuEntryAssessment getAssessment(VastuEntrySegment segment);
}
