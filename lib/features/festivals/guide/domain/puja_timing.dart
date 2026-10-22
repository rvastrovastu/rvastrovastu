import '../../../panchang/domain/entities/day_divisions.dart';
import '../../domain/entities/calendar_observance.dart';

/// The traditional window in which an observance's main puja is done.
enum PujaTimeRule {
  /// Pratah kaal: the first fifth of the day after sunrise.
  morning,

  /// Madhyahna: the middle (third) fifth of the day.
  midday,

  /// Pradosh kaal: three muhurtas (a fifth of the night) after sunset.
  pradosh,

  /// Nishita kaal: the eighth of the fifteen night muhurtas, around
  /// local midnight.
  nishita,

  /// After moonrise (Karva Chauth, Sankashti).
  moonrise,
}

PujaTimeRule pujaTimeRuleFor(ObservanceId id) => switch (id) {
  ObservanceId.mahaShivaratri ||
  ObservanceId.masikShivaratri ||
  ObservanceId.janmashtami => PujaTimeRule.nishita,
  ObservanceId.holi ||
  ObservanceId.dhanteras ||
  ObservanceId.diwali ||
  ObservanceId.pradosh => PujaTimeRule.pradosh,
  ObservanceId.karvaChauth || ObservanceId.sankashti => PujaTimeRule.moonrise,
  ObservanceId.ramNavami ||
  ObservanceId.ganeshChaturthi ||
  ObservanceId.dussehra ||
  ObservanceId.rakshaBandhan ||
  ObservanceId.amavasya => PujaTimeRule.midday,
  _ => PujaTimeRule.morning,
};

/// A start–end window in UTC.
class TimeWindow {
  final DateTime start;
  final DateTime end;

  const TimeWindow(this.start, this.end);

  bool overlaps(TimeWindow other) =>
      start.isBefore(other.end) && other.start.isBefore(end);
}

/// The puja window for [rule] on the Vedic day described by [sun], or null
/// for [PujaTimeRule.moonrise] (which comes from the Moon, not the Sun).
TimeWindow? pujaWindow(PujaTimeRule rule, SunTimes sun) {
  final day = sun.sunset.difference(sun.sunrise);
  final night = sun.nextSunrise.difference(sun.sunset);
  final dayFifth = day ~/ 5;
  final nightMuhurta = night ~/ 15;

  return switch (rule) {
    PujaTimeRule.morning => TimeWindow(sun.sunrise, sun.sunrise.add(dayFifth)),
    PujaTimeRule.midday => TimeWindow(
      sun.sunrise.add(dayFifth * 2),
      sun.sunrise.add(dayFifth * 3),
    ),
    PujaTimeRule.pradosh => TimeWindow(
      sun.sunset,
      sun.sunset.add(nightMuhurta * 3),
    ),
    PujaTimeRule.nishita => TimeWindow(
      sun.sunset.add(nightMuhurta * 7),
      sun.sunset.add(nightMuhurta * 8),
    ),
    PujaTimeRule.moonrise => null,
  };
}

/// The day's inauspicious periods, keyed 'rahuKaal', 'yamaganda' and
/// 'gulika'.
List<(String, TimeWindow)> periodsToAvoid(DayDivisions day) => [
  ('rahuKaal', rahuKaalOf(day)),
  ('yamaganda', TimeWindow(day.yamaganda.start, day.yamaganda.end)),
  ('gulika', TimeWindow(day.gulika.start, day.gulika.end)),
];

/// Rahu Kaal: an eighth of the daytime, which eighth depending on the
/// weekday (Sunday first).
TimeWindow rahuKaalOf(DayDivisions day) {
  const segment = [8, 2, 7, 5, 6, 4, 3];
  final w = day.weekday % 7;
  final eighth = day.sun.sunset.difference(day.sun.sunrise) ~/ 8;
  final start = day.sun.sunrise.add(eighth * (segment[w] - 1));
  return TimeWindow(start, start.add(eighth));
}
