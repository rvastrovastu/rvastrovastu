import '../entities/dasha_period.dart';
import '../entities/dasha_timeline.dart';
import 'calculate_current_dasha.dart';
import 'calculate_vimshottari_dasha.dart';

/// The next change of period someone will feel: a new antardasha, or a
/// new mahadasha when the antardasha ending is the last of its mahadasha.
class DashaChange {
  final DashaPlanet planet;
  final DateTime date;
  final bool isMahadasha;

  const DashaChange({
    required this.planet,
    required this.date,
    required this.isMahadasha,
  });
}

/// The next dasha change within [within] of [now], or null when none falls
/// in that window.
DashaChange? nextDashaChange(
  DashaTimeline timeline,
  DateTime now, {
  Duration within = const Duration(days: 60),
}) {
  final current = CalculateCurrentDasha()(timeline: timeline, date: now);
  final maha = current.mahadasha;
  final antar = current.antardasha;
  if (maha == null || antar == null) return null;
  if (antar.endDate.isAfter(now.add(within))) return null;

  final antardashas = CalculateVimshottariDasha().antardashas(maha);
  final index = antardashas.indexWhere(
    (p) => p.startDate == antar.startDate && p.planet == antar.planet,
  );
  final isLast = index == -1 || index == antardashas.length - 1;

  if (!isLast) {
    return DashaChange(
      planet: antardashas.elementAt(index + 1).planet,
      date: antar.endDate,
      isMahadasha: false,
    );
  }

  final mahas = timeline.periods.where((p) => p.level == 1).toList();
  final mahaIndex = mahas.indexWhere((p) => p.startDate == maha.startDate);
  if (mahaIndex == -1 || mahaIndex == mahas.length - 1) return null;
  return DashaChange(
    planet: mahas.elementAt(mahaIndex + 1).planet,
    date: maha.endDate,
    isMahadasha: true,
  );
}
