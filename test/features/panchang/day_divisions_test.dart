import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/day_divisions.dart';

/// A 12-hour day from 06:00 to 18:00 UTC and a 12-hour night, so every
/// Choghadiya is 90 minutes and every Hora is an hour.
SunTimes _evenDay() => SunTimes(
  sunrise: DateTime.utc(2026, 10, 18, 6),
  sunset: DateTime.utc(2026, 10, 18, 18),
  nextSunrise: DateTime.utc(2026, 10, 19, 6),
);

void main() {
  test('Sunday day and night Choghadiya follow the classical tables', () {
    final d = DayDivisions.calculate(_evenDay(), DateTime.sunday);

    expect(d.dayChoghadiya.map((p) => p.value), [
      Choghadiya.udveg,
      Choghadiya.chal,
      Choghadiya.labh,
      Choghadiya.amrit,
      Choghadiya.kaal,
      Choghadiya.shubh,
      Choghadiya.rog,
      Choghadiya.udveg,
    ]);
    expect(d.nightChoghadiya.map((p) => p.value), [
      Choghadiya.shubh,
      Choghadiya.amrit,
      Choghadiya.chal,
      Choghadiya.rog,
      Choghadiya.kaal,
      Choghadiya.labh,
      Choghadiya.udveg,
      Choghadiya.shubh,
    ]);
    expect(d.dayChoghadiya[1].start, DateTime.utc(2026, 10, 18, 7, 30));
    expect(d.nightChoghadiya.last.end, DateTime.utc(2026, 10, 19, 6));
  });

  test('first day and night Choghadiya for every weekday', () {
    const day = {
      DateTime.sunday: Choghadiya.udveg,
      DateTime.monday: Choghadiya.amrit,
      DateTime.tuesday: Choghadiya.rog,
      DateTime.wednesday: Choghadiya.labh,
      DateTime.thursday: Choghadiya.shubh,
      DateTime.friday: Choghadiya.chal,
      DateTime.saturday: Choghadiya.kaal,
    };
    const night = {
      DateTime.sunday: Choghadiya.shubh,
      DateTime.monday: Choghadiya.chal,
      DateTime.tuesday: Choghadiya.kaal,
      DateTime.wednesday: Choghadiya.udveg,
      DateTime.thursday: Choghadiya.amrit,
      DateTime.friday: Choghadiya.rog,
      DateTime.saturday: Choghadiya.labh,
    };
    for (final weekday in day.keys) {
      final d = DayDivisions.calculate(_evenDay(), weekday);
      expect(d.dayChoghadiya.first.value, day[weekday], reason: '$weekday');
      expect(d.nightChoghadiya.first.value, night[weekday], reason: '$weekday');
      // The day's first and last Choghadiya are always the same.
      expect(d.dayChoghadiya.last.value, d.dayChoghadiya.first.value);
    }
  });

  test('Monday Hora starts with the Moon and the night continues the run', () {
    final d = DayDivisions.calculate(_evenDay(), DateTime.monday);

    expect(d.dayHoras.take(8).map((h) => h.value), [
      'Moon',
      'Saturn',
      'Jupiter',
      'Mars',
      'Sun',
      'Venus',
      'Mercury',
      'Moon',
    ]);
    expect(d.dayHoras[3].start, DateTime.utc(2026, 10, 18, 9));
    // The night continues the run, ending just before Tuesday's lord.
    expect(d.nightHoras.first.value, 'Venus');
    expect(d.nightHoras.last.value, 'Jupiter');
  });

  test('every weekday begins with its own lord', () {
    for (var weekday = 1; weekday <= 7; weekday++) {
      final d = DayDivisions.calculate(_evenDay(), weekday);
      expect(d.dayHoras.first.value, DayDivisions.weekdayLords[weekday % 7]);
    }
  });

  test('Yamaganda and Gulika use the traditional eighths', () {
    DateTime h(int hour, [int minute = 0]) =>
        DateTime.utc(2026, 10, 18, hour, minute);

    final sunday = DayDivisions.calculate(_evenDay(), DateTime.sunday);
    expect(sunday.yamaganda.start, h(12));
    expect(sunday.yamaganda.end, h(13, 30));
    expect(sunday.gulika.start, h(15));

    final thursday = DayDivisions.calculate(_evenDay(), DateTime.thursday);
    expect(thursday.yamaganda.start, h(6));
    expect(thursday.gulika.start, h(9));

    final saturday = DayDivisions.calculate(_evenDay(), DateTime.saturday);
    expect(saturday.yamaganda.start, h(13, 30));
    expect(saturday.gulika.start, h(6));
  });

  test('contains and isNight', () {
    final d = DayDivisions.calculate(_evenDay(), DateTime.sunday);
    expect(d.sun.contains(DateTime.utc(2026, 10, 19, 5)), isTrue);
    expect(d.sun.contains(DateTime.utc(2026, 10, 19, 6)), isFalse);
    expect(d.isNight(DateTime.utc(2026, 10, 18, 17, 59)), isFalse);
    expect(d.isNight(DateTime.utc(2026, 10, 18, 18)), isTrue);
    expect(d.dayChoghadiya[0].contains(DateTime.utc(2026, 10, 18, 7)), isTrue);
  });

  test('rejects sun times out of order', () {
    expect(
      () => SunTimes(
        sunrise: DateTime.utc(2026, 1, 1, 18),
        sunset: DateTime.utc(2026, 1, 1, 6),
        nextSunrise: DateTime.utc(2026, 1, 2, 6),
      ),
      throwsArgumentError,
    );
  });
}
