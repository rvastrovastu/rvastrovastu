import 'vastu_entry_direction.dart';
import 'vastu_entry_segment.dart';

enum VastuAssessmentLevel { favorable, neutral, challenging }

class VastuEntryAssessment {
  const VastuEntryAssessment({
    required this.segment,
    required this.level,
    required this.deityKey,
    required this.summaryKey,
  });

  final VastuEntrySegment segment;
  final VastuAssessmentLevel level;
  final String deityKey;
  final String summaryKey;

  VastuEntryDirection get direction => segment.direction;
}
