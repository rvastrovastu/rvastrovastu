import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dasha_birth_data.dart';
import '../../domain/entities/dasha_period.dart';
import '../../domain/entities/dasha_timeline.dart';
import '../../domain/usecases/calculate_current_dasha.dart';
import '../../domain/usecases/calculate_vimshottari_dasha.dart';

final dashaTimelineProvider = Provider.family<DashaTimeline, DashaBirthData>((
  ref,
  birthData,
) {
  return CalculateVimshottariDasha().call(birthData: birthData);
});

final currentDashaResultProvider =
    Provider.family<CurrentDashaResult, DashaBirthData>((ref, birthData) {
      final timeline = ref.watch(dashaTimelineProvider(birthData));

      return CalculateCurrentDasha().call(timeline: timeline);
    });

final currentDashaProvider = Provider.family<DashaPeriod?, DashaBirthData>((
  ref,
  birthData,
) {
  return ref.watch(currentDashaResultProvider(birthData)).mahadasha;
});

final currentAntardashaProvider = Provider.family<DashaPeriod?, DashaBirthData>(
  (ref, birthData) {
    return ref.watch(currentDashaResultProvider(birthData)).antardasha;
  },
);
