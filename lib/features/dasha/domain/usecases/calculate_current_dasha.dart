import '../entities/dasha_period.dart';
import '../entities/dasha_timeline.dart';
import 'calculate_vimshottari_dasha.dart';

class CurrentDashaResult {
  final DashaPeriod? mahadasha;
  final DashaPeriod? antardasha;

  const CurrentDashaResult({required this.mahadasha, required this.antardasha});
}

class CalculateCurrentDasha {
  CurrentDashaResult call({required DashaTimeline timeline, DateTime? date}) {
    final targetDate = date ?? DateTime.now();

    DashaPeriod? mahadasha;

    for (final period in timeline.periods) {
      if (period.level == 1 && period.contains(targetDate)) {
        mahadasha = period;
        break;
      }
    }

    if (mahadasha == null) {
      return const CurrentDashaResult(mahadasha: null, antardasha: null);
    }

    final antardashas = CalculateVimshottariDasha().antardashas(mahadasha);

    DashaPeriod? antardasha;

    for (final period in antardashas) {
      if (period.contains(targetDate)) {
        antardasha = period;
        break;
      }
    }

    return CurrentDashaResult(mahadasha: mahadasha, antardasha: antardasha);
  }

  /// Backwards-compatible helper.
  DashaPeriod? currentMahadasha({
    required DashaTimeline timeline,
    DateTime? date,
  }) {
    return call(timeline: timeline, date: date).mahadasha;
  }
}
