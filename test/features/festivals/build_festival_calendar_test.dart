import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/festivals/domain/entities/calendar_observance.dart';
import 'package:rv_astro_vastu/features/festivals/domain/entities/lunar_calendar_data.dart';
import 'package:rv_astro_vastu/features/festivals/domain/usecases/build_festival_calendar.dart';

/// Synthetic data: days with sunrise 06:00 and sunset 18:00 UTC, and a
/// tithi schedule built from explicit (index, start, end) intervals.
DateTime _t(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2030, 1, day, hour, minute);

List<SolarDay> _days(int count) => [
  for (var d = 1; d <= count; d++)
    SolarDay(
      date: DateTime(2030, 1, d),
      sunrise: _t(d, 6),
      sunset: _t(d, 18),
      nextSunrise: _t(d + 1, 6),
      moonrise: _t(d, 20),
    ),
];

/// One tithi per day starting at 03:00, so each sunrise sees exactly one.
List<TithiSegment> _dailyTithis(int firstIndex, int count) {
  return [
    for (var i = 0; i < count; i++)
      TithiSegment(
        index: (firstIndex + i) % 30,
        start: _t(1 + i, 3),
        end: _t(2 + i, 3),
      ),
  ];
}

void main() {
  const build = BuildFestivalCalendar();

  // New moon on Jan 1 with the Sun in Virgo (5) → amanta Ashvin.
  // Next new moon on Jan 31 with the Sun in Libra (6) → Kartika.
  final ashvinNewMoons = [
    NewMoon(time: _t(1, 2), sunSignIndex: 5),
    NewMoon(time: _t(31, 2), sunSignIndex: 6),
  ];

  test('Shukla Dashami in Ashvin is Dussehra; Amavasya is Diwali', () {
    final data = LunarCalendarData(
      tithis: _dailyTithis(0, 30),
      newMoons: ashvinNewMoons,
      sankrantis: const [],
      days: _days(31),
    );

    final result = build(
      data,
      fromDate: DateTime(2030, 1, 1),
      toDate: DateTime(2030, 1, 31),
    );

    final byId = {for (final o in result) o.id: o.date};
    expect(byId[ObservanceId.navratri], DateTime(2030, 1, 1)); // tithi 0
    expect(byId[ObservanceId.dussehra], DateTime(2030, 1, 10)); // tithi 9
    expect(byId[ObservanceId.karvaChauth], DateTime(2030, 1, 19)); // 18
    expect(byId[ObservanceId.diwali], DateTime(2030, 1, 30)); // 29
    expect(byId.containsKey(ObservanceId.holi), isFalse);
  });

  test('recurring vrats appear in every paksha', () {
    final data = LunarCalendarData(
      tithis: _dailyTithis(0, 30),
      newMoons: ashvinNewMoons,
      sankrantis: const [],
      days: _days(31),
    );

    final result = build(
      data,
      fromDate: DateTime(2030, 1, 1),
      toDate: DateTime(2030, 1, 31),
    );

    List<DateTime> datesOf(ObservanceId id) =>
        [for (final o in result) if (o.id == id) o.date];

    expect(datesOf(ObservanceId.ekadashi), [
      DateTime(2030, 1, 11),
      DateTime(2030, 1, 26),
    ]);
    expect(datesOf(ObservanceId.purnima), [DateTime(2030, 1, 15)]);
    expect(datesOf(ObservanceId.pradosh), hasLength(2));
  });

  test('a kshaya tithi falls on the day it begins', () {
    // Tithi 10 (Ekadashi) runs 07:00–23:00 on Jan 11 and touches no
    // sunrise; tithi 9 covers both the Jan 10 and Jan 11 sunrises.
    final tithis = [
      ..._dailyTithis(0, 9),
      TithiSegment(index: 9, start: _t(10, 3), end: _t(11, 7)),
      TithiSegment(index: 10, start: _t(11, 7), end: _t(11, 23)),
      TithiSegment(index: 11, start: _t(11, 23), end: _t(13, 3)),
    ];
    final data = LunarCalendarData(
      tithis: tithis,
      newMoons: ashvinNewMoons,
      sankrantis: const [],
      days: _days(13),
    );

    final result = build(
      data,
      fromDate: DateTime(2030, 1, 1),
      toDate: DateTime(2030, 1, 13),
    );

    expect(
      [
        for (final o in result)
          if (o.id == ObservanceId.ekadashi) o.date,
      ],
      [DateTime(2030, 1, 11)],
    );
  });

  test('festivals are skipped in an Adhik month, vrats are not', () {
    // Two consecutive new moons with the Sun in the same sign → Adhik.
    final data = LunarCalendarData(
      tithis: _dailyTithis(0, 30),
      newMoons: [
        NewMoon(time: _t(1, 2), sunSignIndex: 5),
        NewMoon(time: _t(31, 2), sunSignIndex: 5),
      ],
      sankrantis: const [],
      days: _days(31),
    );

    final result = build(
      data,
      fromDate: DateTime(2030, 1, 1),
      toDate: DateTime(2030, 1, 31),
    );

    expect(result.where((o) => o.id == ObservanceId.diwali), isEmpty);
    expect(result.where((o) => o.id == ObservanceId.ekadashi), hasLength(2));
  });

  test('a named Ekadashi replaces the generic one on that day', () {
    // Sun in Taurus (1) → Jyeshtha, whose Shukla Ekadashi is Nirjala.
    final data = LunarCalendarData(
      tithis: _dailyTithis(0, 30),
      newMoons: [
        NewMoon(time: _t(1, 2), sunSignIndex: 1),
        NewMoon(time: _t(31, 2), sunSignIndex: 2),
      ],
      sankrantis: const [],
      days: _days(31),
    );

    final result = build(
      data,
      fromDate: DateTime(2030, 1, 1),
      toDate: DateTime(2030, 1, 31),
    );

    final onDay11 = result.where((o) => o.date == DateTime(2030, 1, 11));
    expect(onDay11.map((o) => o.id), [ObservanceId.nirjalaEkadashi]);
  });

  test('Makar Sankranti comes from the Sun entering Capricorn', () {
    final data = LunarCalendarData(
      tithis: _dailyTithis(0, 30),
      newMoons: ashvinNewMoons,
      sankrantis: [
        Sankranti(
          time: _t(14, 9),
          localDate: DateTime(2030, 1, 14),
          signIndex: 9,
        ),
        Sankranti(
          time: _t(20, 9),
          localDate: DateTime(2030, 1, 20),
          signIndex: 10,
        ),
      ],
      days: _days(31),
    );

    final result = build(
      data,
      fromDate: DateTime(2030, 1, 1),
      toDate: DateTime(2030, 1, 31),
    );

    final sankranti = result.where(
      (o) => o.id == ObservanceId.makarSankranti,
    );
    expect(sankranti.map((o) => o.date), [DateTime(2030, 1, 14)]);
  });

  test('results are limited to the requested range and sorted', () {
    final data = LunarCalendarData(
      tithis: _dailyTithis(0, 30),
      newMoons: ashvinNewMoons,
      sankrantis: const [],
      days: _days(31),
    );

    final result = build(
      data,
      fromDate: DateTime(2030, 1, 10),
      toDate: DateTime(2030, 1, 20),
    );

    expect(result, isNotEmpty);
    expect(
      result.every(
        (o) =>
            !o.date.isBefore(DateTime(2030, 1, 10)) &&
            !o.date.isAfter(DateTime(2030, 1, 20)),
      ),
      isTrue,
    );
    for (var i = 1; i < result.length; i++) {
      expect(result[i - 1].date.isAfter(result[i].date), isFalse);
    }
  });
}
