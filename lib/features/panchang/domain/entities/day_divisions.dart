/// Sunrise-based divisions of the Vedic day: Choghadiya, Hora, Yamaganda
/// and Gulika Kaal.
///
/// The Vedic day runs from one sunrise to the next, and its weekday is
/// the weekday of that sunrise. Every period here is an equal share of the
/// daytime (sunrise → sunset) or the night (sunset → next sunrise).
library;

/// The three instants a Vedic day is built from, in UTC.
class SunTimes {
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime nextSunrise;

  SunTimes({
    required DateTime sunrise,
    required DateTime sunset,
    required DateTime nextSunrise,
  }) : sunrise = sunrise.toUtc(),
       sunset = sunset.toUtc(),
       nextSunrise = nextSunrise.toUtc() {
    if (!this.sunrise.isBefore(this.sunset) ||
        !this.sunset.isBefore(this.nextSunrise)) {
      throw ArgumentError('Expected sunrise < sunset < next sunrise.');
    }
  }

  bool contains(DateTime instant) {
    final t = instant.toUtc();
    return !t.isBefore(sunrise) && t.isBefore(nextSunrise);
  }
}

enum ChoghadiyaQuality { good, neutral, bad }

enum Choghadiya {
  udveg(ChoghadiyaQuality.bad),
  chal(ChoghadiyaQuality.neutral),
  labh(ChoghadiyaQuality.good),
  amrit(ChoghadiyaQuality.good),
  kaal(ChoghadiyaQuality.bad),
  shubh(ChoghadiyaQuality.good),
  rog(ChoghadiyaQuality.bad);

  final ChoghadiyaQuality quality;

  const Choghadiya(this.quality);
}

/// One timed slot holding a value (a Choghadiya, a planet, …).
class TimedPeriod<T> {
  final DateTime start;
  final DateTime end;
  final T value;

  const TimedPeriod(this.start, this.end, this.value);

  bool contains(DateTime instant) {
    final t = instant.toUtc();
    return !t.isBefore(start) && t.isBefore(end);
  }
}

class DayDivisions {
  /// Weekday of the sunrise (DateTime.monday … DateTime.sunday).
  final int weekday;
  final SunTimes sun;
  final List<TimedPeriod<Choghadiya>> dayChoghadiya;
  final List<TimedPeriod<Choghadiya>> nightChoghadiya;

  /// Planet names as used across the app ('Sun', 'Venus', …).
  final List<TimedPeriod<String>> dayHoras;
  final List<TimedPeriod<String>> nightHoras;
  final TimedPeriod<void> yamaganda;
  final TimedPeriod<void> gulika;

  const DayDivisions._({
    required this.weekday,
    required this.sun,
    required this.dayChoghadiya,
    required this.nightChoghadiya,
    required this.dayHoras,
    required this.nightHoras,
    required this.yamaganda,
    required this.gulika,
  });

  /// [weekday] is the weekday of [sun].sunrise in the place's local time.
  factory DayDivisions.calculate(SunTimes sun, int weekday) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw ArgumentError.value(weekday, 'weekday');
    }
    final w = weekday % 7; // Sunday 0 … Saturday 6

    final daySlots = _split(sun.sunrise, sun.sunset, 8);
    final nightSlots = _split(sun.sunset, sun.nextSunrise, 8);

    final dayStart = _dayChoghadiyaCycle.indexOf(_dayChoghadiyaStart[w]);
    final nightStart = _nightChoghadiyaCycle.indexOf(_nightChoghadiyaStart[w]);

    final horaStart = _horaOrder.indexOf(weekdayLords[w]);
    final dayHoraSlots = _split(sun.sunrise, sun.sunset, 12);
    final nightHoraSlots = _split(sun.sunset, sun.nextSunrise, 12);

    final yama = daySlots[_yamagandaSegment[w] - 1];
    final gulika = daySlots[_gulikaSegment[w] - 1];

    return DayDivisions._(
      weekday: weekday,
      sun: sun,
      dayChoghadiya: [
        for (var i = 0; i < 8; i++)
          TimedPeriod(
            daySlots[i].$1,
            daySlots[i].$2,
            _dayChoghadiyaCycle[(dayStart + i) % 7],
          ),
      ],
      nightChoghadiya: [
        for (var i = 0; i < 8; i++)
          TimedPeriod(
            nightSlots[i].$1,
            nightSlots[i].$2,
            _nightChoghadiyaCycle[(nightStart + i) % 7],
          ),
      ],
      dayHoras: [
        for (var i = 0; i < 12; i++)
          TimedPeriod(
            dayHoraSlots[i].$1,
            dayHoraSlots[i].$2,
            _horaOrder[(horaStart + i) % 7],
          ),
      ],
      nightHoras: [
        for (var i = 0; i < 12; i++)
          TimedPeriod(
            nightHoraSlots[i].$1,
            nightHoraSlots[i].$2,
            _horaOrder[(horaStart + 12 + i) % 7],
          ),
      ],
      yamaganda: TimedPeriod<void>(yama.$1, yama.$2, null),
      gulika: TimedPeriod<void>(gulika.$1, gulika.$2, null),
    );
  }

  bool isNight(DateTime instant) => !instant.toUtc().isBefore(sun.sunset);

  /// Lords of the weekdays, Sunday first.
  static const weekdayLords = [
    'Sun',
    'Moon',
    'Mars',
    'Mercury',
    'Jupiter',
    'Venus',
    'Saturn',
  ];

  /// Each hora passes to the next planet in this order (the Chaldean
  /// order, fastest-to-slowest reversed), which is why the first hora of
  /// the next day belongs to the next weekday lord.
  static const _horaOrder = [
    'Sun',
    'Venus',
    'Mercury',
    'Moon',
    'Saturn',
    'Jupiter',
    'Mars',
  ];

  static const _dayChoghadiyaCycle = [
    Choghadiya.udveg,
    Choghadiya.chal,
    Choghadiya.labh,
    Choghadiya.amrit,
    Choghadiya.kaal,
    Choghadiya.shubh,
    Choghadiya.rog,
  ];

  static const _nightChoghadiyaCycle = [
    Choghadiya.shubh,
    Choghadiya.amrit,
    Choghadiya.chal,
    Choghadiya.rog,
    Choghadiya.kaal,
    Choghadiya.labh,
    Choghadiya.udveg,
  ];

  /// First daytime Choghadiya, Sunday first.
  static const _dayChoghadiyaStart = [
    Choghadiya.udveg,
    Choghadiya.amrit,
    Choghadiya.rog,
    Choghadiya.labh,
    Choghadiya.shubh,
    Choghadiya.chal,
    Choghadiya.kaal,
  ];

  /// First night Choghadiya, Sunday first.
  static const _nightChoghadiyaStart = [
    Choghadiya.shubh,
    Choghadiya.chal,
    Choghadiya.kaal,
    Choghadiya.udveg,
    Choghadiya.amrit,
    Choghadiya.rog,
    Choghadiya.labh,
  ];

  /// 1-based eighth of the daytime, Sunday first.
  static const _yamagandaSegment = [5, 4, 3, 2, 1, 7, 6];
  static const _gulikaSegment = [7, 6, 5, 4, 3, 2, 1];

  static List<(DateTime, DateTime)> _split(
    DateTime start,
    DateTime end,
    int parts,
  ) {
    final total = end.difference(start).inMicroseconds;
    DateTime at(int i) =>
        start.add(Duration(microseconds: (total * i / parts).round()));
    return [for (var i = 0; i < parts; i++) (at(i), at(i + 1))];
  }
}
