import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/festivals/domain/entities/lunar_calendar_data.dart';
import 'package:rv_astro_vastu/features/festivals/domain/usecases/build_festival_calendar.dart';
import 'package:rv_astro_vastu/features/festivals/month/hindu_month.dart';

void main() {
  // Two days: sunrise on the 1st falls in Shukla Dashami (9), on the 2nd
  // in Krishna Pratipada (15). The new moon before had the Sun in Virgo
  // (5), so the Amanta month is Ashvin.
  final data = LunarCalendarData(
    tithis: [
      TithiSegment(
        index: 9,
        start: DateTime.utc(2026, 10, 1),
        end: DateTime.utc(2026, 10, 2),
      ),
      TithiSegment(
        index: 15,
        start: DateTime.utc(2026, 10, 2),
        end: DateTime.utc(2026, 10, 3),
      ),
    ],
    newMoons: [
      NewMoon(time: DateTime.utc(2026, 9, 20), sunSignIndex: 5),
      NewMoon(time: DateTime.utc(2026, 10, 20), sunSignIndex: 6),
    ],
    sankrantis: const [],
    days: [
      SolarDay(date: DateTime(2026, 9, 30), sunrise: DateTime.utc(2026, 9, 30, 1)),
      SolarDay(date: DateTime(2026, 10, 1), sunrise: DateTime.utc(2026, 10, 1, 1)),
      SolarDay(date: DateTime(2026, 10, 2), sunrise: DateTime.utc(2026, 10, 2, 1)),
    ],
  );

  test('days of the month get their sunrise tithi and month', () {
    final days = buildHinduMonth(data, 2026, 10);
    expect(days, hasLength(2));
    expect(days.first.tithi, 9);
    expect(days.first.month, LunarMonth.ashvin);
    expect(days.first.purnimantaMonth, LunarMonth.ashvin);
    expect(days.first.tithiInPaksha, 10);

    // The dark half belongs to the next month in Purnimanta.
    expect(days.last.month, LunarMonth.ashvin);
    expect(days.last.purnimantaMonth, LunarMonth.kartika);
    expect(days.last.isShukla, isFalse);
  });

  test('tithi names match the Panchang', () {
    expect(tithiCanonicalName(0), 'Shukla Pratipada');
    expect(tithiCanonicalName(14), 'Purnima');
    expect(tithiCanonicalName(20), 'Krishna Shashthi');
    expect(tithiCanonicalName(29), 'Amavasya');
  });
}
