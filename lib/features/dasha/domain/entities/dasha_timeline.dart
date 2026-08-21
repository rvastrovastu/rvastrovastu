import 'dasha_period.dart';

class DashaTimeline {
  final List<DashaPeriod> periods;

  const DashaTimeline({required this.periods});

  DashaPeriod? periodAt(DateTime date) {
    for (final period in periods) {
      if (period.contains(date)) {
        return period;
      }
    }

    return null;
  }

  List<DashaPeriod> get majorPeriods => periods;
}
