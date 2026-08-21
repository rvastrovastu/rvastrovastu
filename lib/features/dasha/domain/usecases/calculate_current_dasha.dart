import '../entities/dasha_period.dart';
import '../entities/dasha_timeline.dart';

class CalculateCurrentDasha {
  DashaPeriod? call({
    required DashaTimeline timeline,
    DateTime? date,
  }) {
    final targetDate = date ?? DateTime.now();

    for (final period in timeline.periods) {
      final startsBeforeOrAt =
          !targetDate.isBefore(period.startDate);

      final endsAfter =
          targetDate.isBefore(period.endDate);

      if (startsBeforeOrAt && endsAfter) {
        return period;
      }
    }

    return null;
  }
}