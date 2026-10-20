import 'dasha_period.dart';

class DashaInsight {
  final DashaPeriod? mahadasha;
  final DashaPeriod? antardasha;
  final String focus;
  final String career;
  final String finance;
  final String relationships;

  const DashaInsight({
    required this.mahadasha,
    required this.antardasha,
    required this.focus,
    required this.career,
    required this.finance,
    required this.relationships,
  });

  bool get hasCurrentPeriod => mahadasha != null;
}
