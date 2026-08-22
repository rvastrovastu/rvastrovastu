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

final dashaReferenceDateProvider = Provider<DateTime>((ref) {
  return DateTime.now();
});

final currentDashaResultProvider =
    Provider.family<CurrentDashaResult, DashaBirthData>((ref, birthData) {
      final timeline = ref.watch(dashaTimelineProvider(birthData));
      final referenceDate = ref.watch(dashaReferenceDateProvider);

      return CalculateCurrentDasha().call(
        timeline: timeline,
        date: referenceDate,
      );
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

final antardashaTimelineProvider =
    Provider.family<List<DashaPeriod>, DashaPeriod>((ref, mahadasha) {
      return CalculateVimshottariDasha().antardashas(mahadasha);
    });

final pratyantardashaTimelineProvider =
    Provider.family<List<DashaPeriod>, DashaPeriod>((ref, antardasha) {
      return CalculateVimshottariDasha().pratyantardashas(antardasha);
    });
