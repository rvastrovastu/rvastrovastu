/// The daily loop's small pieces: today's free remedy, the remedy streak
/// and the night check-in record.
library;

import '../../panchang/domain/entities/day_divisions.dart';

/// How today's remedy is practised.
enum RemedyKind { mantra, charity, worship }

/// One small, free practice for today.
class DailyRemedy {
  /// Lower-case planet key ('saturn', …), as the remedies strings use.
  final String planet;
  final RemedyKind kind;

  /// True when [planet] is the user's running dasha lord; false when it is
  /// simply the weekday's planet.
  final bool forDasha;

  const DailyRemedy({
    required this.planet,
    required this.kind,
    required this.forDasha,
  });
}

/// Picks today's remedy: for the running antardasha lord (else the
/// mahadasha lord, else the weekday's planet), with the practice rotating
/// day by day between a mantra, a small charity and worship.
DailyRemedy pickDailyRemedy({
  required DateTime date,
  String? mahadasha,
  String? antardasha,
}) {
  String? usable(String? planet) {
    final value = planet?.trim();
    if (value == null || value.isEmpty || value == 'Unknown') return null;
    return value.toLowerCase();
  }

  final dasha = usable(antardasha) ?? usable(mahadasha);
  final weekdayLord = DayDivisions.weekdayLords[date.weekday % 7]
      .toLowerCase();
  final day = DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(2000))
      .inDays;

  return DailyRemedy(
    planet: dasha ?? weekdayLord,
    kind: RemedyKind.values[day % RemedyKind.values.length],
    forDasha: dasha != null,
  );
}

/// The answer to "Did today match your reading?".
enum CheckIn { yes, partly, no }

/// 'yyyy-mm-dd' for a local calendar date.
String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Days in a row the remedy was done, ending today, or ending yesterday
/// while today is still open.
int remedyStreak(Set<String> doneDays, DateTime today) {
  var day = DateTime(today.year, today.month, today.day);
  if (!doneDays.contains(dayKey(day))) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var streak = 0;
  while (doneDays.contains(dayKey(day))) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

/// How well readings matched over the last [window] days up to [today]:
/// yes counts 1, partly a half. Null with fewer than [minimum] answers.
({int percent, int days})? matchRate(
  Map<String, CheckIn> checkIns,
  DateTime today, {
  int window = 30,
  int minimum = 3,
}) {
  var count = 0;
  var points = 0.0;
  for (var i = 0; i < window; i++) {
    final answer =
        checkIns[dayKey(DateTime(today.year, today.month, today.day - i))];
    if (answer == null) continue;
    count++;
    points += switch (answer) {
      CheckIn.yes => 1,
      CheckIn.partly => 0.5,
      CheckIn.no => 0,
    };
  }
  if (count < minimum) return null;
  return (percent: (points / count * 100).round(), days: count);
}
