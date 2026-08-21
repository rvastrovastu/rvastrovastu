import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dasha_period.dart';
import '../../domain/entities/dasha_timeline.dart';
import '../../domain/usecases/calculate_current_dasha.dart';
import '../../domain/usecases/calculate_vimshottari_dasha.dart';

final dashaTimelineProvider = Provider.family<DashaTimeline, DateTime>((
  ref,
  birthDate,
) {
  return CalculateVimshottariDasha().call(birthDate: birthDate);
});

final currentDashaProvider = Provider.family<DashaPeriod?, DateTime>((
  ref,
  birthDate,
) {
  final timeline = ref.watch(dashaTimelineProvider(birthDate));

  final result = CalculateCurrentDasha().call(timeline: timeline);

  return result.mahadasha;
});
