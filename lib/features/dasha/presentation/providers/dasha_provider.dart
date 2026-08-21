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

final currentDashaResultProvider =
    Provider.family<CurrentDashaResult, DateTime>((ref, birthDate) {
      final timeline = ref.watch(dashaTimelineProvider(birthDate));

      return CalculateCurrentDasha().call(timeline: timeline);
    });

final currentDashaProvider = Provider.family<DashaPeriod?, DateTime>((
  ref,
  birthDate,
) {
  return ref.watch(currentDashaResultProvider(birthDate)).mahadasha;
});

final currentAntardashaProvider = Provider.family<DashaPeriod?, DateTime>((
  ref,
  birthDate,
) {
  return ref.watch(currentDashaResultProvider(birthDate)).antardasha;
});
