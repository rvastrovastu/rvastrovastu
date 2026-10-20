import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/local_vastu_entry_deity_repository.dart';
import '../../data/repositories/local_vastu_entry_repository.dart';
import '../../domain/entities/vastu_entry_assessment.dart';
import '../../domain/entities/vastu_entry_deity.dart';
import '../../domain/entities/vastu_entry_segment.dart';
import '../../domain/repositories/vastu_entry_repository.dart';
import '../../domain/usecases/calculate_vastu_entry_pada.dart';
import '../../domain/usecases/calculate_vastu_entry_segment.dart';

final vastuEntryRepositoryProvider = Provider<VastuEntryRepository>((ref) {
  return const LocalVastuEntryRepository();
});

final vastuEntryAssessmentProvider =
    Provider.family<VastuEntryAssessment, VastuEntrySegment>((ref, segment) {
      final repository = ref.watch(vastuEntryRepositoryProvider);

      return repository.getAssessment(segment);
    });

final vastuSupportedEntrySegmentsProvider = Provider<List<VastuEntrySegment>>((
  ref,
) {
  final repository = ref.watch(vastuEntryRepositoryProvider);
  return repository.supportedSegments;
});

final calculateVastuEntryPadaProvider = Provider<CalculateVastuEntryPada>((
  ref,
) {
  return const CalculateVastuEntryPada();
});

final calculateVastuEntrySegmentProvider = Provider<CalculateVastuEntrySegment>(
  (ref) {
    return const CalculateVastuEntrySegment();
  },
);

final vastuEntryDeityRepositoryProvider =
    Provider<LocalVastuEntryDeityRepository>((ref) {
      return const LocalVastuEntryDeityRepository();
    });

final vastuEntryDeityProvider =
    Provider.family<VastuEntryDeity, VastuEntrySegment>((ref, segment) {
      final repository = ref.watch(vastuEntryDeityRepositoryProvider);
      return repository.getDeity(segment);
    });
