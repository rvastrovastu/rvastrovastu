import '../../../festivals/domain/entities/calendar_observance.dart';
import '../../../panchang/domain/entities/daily_panchang.dart';
import '../entities/reminder_settings.dart';

enum ReminderKind { morning, festivalEve, vratEve }

class PlannedReminder {
  /// Stable notification id: 1000+ morning, 2000+ festival, 3000+ vrat.
  final int id;
  final ReminderKind kind;

  /// Local wall-clock time at the calendar's place.
  final DateTime at;

  /// Morning reminders: that day's Panchang.
  final DailyPanchang? panchang;

  /// Morning reminders: observances on that day, major festivals first.
  /// Eve reminders: the single observance falling the next day.
  final List<ObservanceId> observances;

  const PlannedReminder({
    required this.id,
    required this.kind,
    required this.at,
    this.panchang,
    this.observances = const [],
  });
}

/// Chooses which notifications to schedule. Pure, so it can be tested
/// without the notification plugin.
///
/// iOS keeps at most 64 pending local notifications, so the plan is capped
/// at [maxReminders], keeping the soonest.
class PlanReminders {
  static const int maxReminders = 60;
  static const int eveHour = 18;
  static const Duration eveHorizon = Duration(days: 60);

  static const Set<ObservanceId> _vratIds = {
    ObservanceId.ekadashi,
    ObservanceId.purnima,
    ObservanceId.amavasya,
    ObservanceId.pradosh,
    ObservanceId.sankashti,
    ObservanceId.masikShivaratri,
  };

  const PlanReminders();

  List<PlannedReminder> call({
    required ReminderSettings settings,
    required DateTime now,
    required List<DailyPanchang> panchangDays,
    required List<CalendarObservance> observances,
  }) {
    final planned = <PlannedReminder>[];

    if (settings.morningEnabled) {
      for (var i = 0; i < panchangDays.length; i++) {
        final day = panchangDays[i];
        final at = DateTime(
          day.date.year,
          day.date.month,
          day.date.day,
          settings.morningHour,
          settings.morningMinute,
        );
        if (!at.isAfter(now)) continue;

        final todays =
            observances.where((o) => _sameDay(o.date, day.date)).toList()
              ..sort((a, b) {
                final major = (b.id.isMajorFestival ? 1 : 0) -
                    (a.id.isMajorFestival ? 1 : 0);
                return major != 0 ? major : a.id.index - b.id.index;
              });

        planned.add(
          PlannedReminder(
            id: 1000 + i,
            kind: ReminderKind.morning,
            at: at,
            panchang: day,
            observances: [for (final o in todays) o.id],
          ),
        );
      }
    }

    final horizon = now.add(eveHorizon);
    final festivalDays = <DateTime>{};

    if (settings.festivalsEnabled) {
      var index = 0;
      for (final o in observances) {
        if (!o.id.isMajorFestival) continue;
        final at = _eveOf(o.date);
        if (!at.isAfter(now) || at.isAfter(horizon)) continue;
        festivalDays.add(_dateOnly(o.date));
        planned.add(
          PlannedReminder(
            id: 2000 + index++,
            kind: ReminderKind.festivalEve,
            at: at,
            observances: [o.id],
          ),
        );
      }
    }

    if (settings.vratsEnabled) {
      var index = 0;
      final vratDays = <DateTime>{};
      for (final o in observances) {
        if (!_vratIds.contains(o.id)) continue;
        final day = _dateOnly(o.date);
        // One evening reminder per day; a festival reminder wins.
        if (festivalDays.contains(day) || !vratDays.add(day)) continue;
        final at = _eveOf(o.date);
        if (!at.isAfter(now) || at.isAfter(horizon)) continue;
        planned.add(
          PlannedReminder(
            id: 3000 + index++,
            kind: ReminderKind.vratEve,
            at: at,
            observances: [o.id],
          ),
        );
      }
    }

    planned.sort((a, b) => a.at.compareTo(b.at));
    return planned.length > maxReminders
        ? planned.sublist(0, maxReminders)
        : planned;
  }

  static DateTime _eveOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - 1, eveHour);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
