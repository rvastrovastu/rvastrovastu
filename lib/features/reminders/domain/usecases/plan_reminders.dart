import '../../../festivals/domain/entities/calendar_observance.dart';
import '../../../panchang/domain/entities/daily_panchang.dart';
import '../entities/reminder_settings.dart';

enum ReminderKind { morning, festivalEve, vratEve, transit }

/// A slow planet changing sign, read from the user's Moon sign.
class TransitAlert {
  final String planet;
  final int signIndex;
  final int houseFromMoon;
  final bool favourable;

  /// Local date of the sign change.
  final DateTime date;

  /// 'start' or 'end' when this Saturn move begins or ends Sade Sati.
  final String? sadeSati;

  const TransitAlert({
    required this.planet,
    required this.signIndex,
    required this.houseFromMoon,
    required this.favourable,
    required this.date,
    this.sadeSati,
  });
}

class PlannedReminder {
  /// Stable notification id: 1000+ morning, 2000+ festival, 3000+ vrat,
  /// 4000+ transit.
  final int id;
  final ReminderKind kind;

  /// Local wall-clock time at the calendar's place.
  final DateTime at;

  /// Morning reminders: that day's Panchang.
  final DailyPanchang? panchang;

  /// Morning reminders: observances on that day, major festivals first.
  /// Eve reminders: the single observance falling the next day.
  final List<ObservanceId> observances;

  /// Transit alerts: the sign change.
  final TransitAlert? transit;

  const PlannedReminder({
    required this.id,
    required this.kind,
    required this.at,
    this.panchang,
    this.observances = const [],
    this.transit,
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
  static const int transitHour = 9;
  static const Duration transitHorizon = Duration(days: 400);

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
    List<TransitAlert> transitAlerts = const [],
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

    if (settings.transitsEnabled) {
      final transitLimit = now.add(transitHorizon);
      var index = 0;
      for (final alert in transitAlerts) {
        final at = DateTime(
          alert.date.year,
          alert.date.month,
          alert.date.day,
          transitHour,
        );
        if (!at.isAfter(now) || at.isAfter(transitLimit)) continue;
        planned.add(
          PlannedReminder(
            id: 4000 + index++,
            kind: ReminderKind.transit,
            at: at,
            transit: alert,
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
