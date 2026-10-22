import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/festivals/domain/entities/calendar_observance.dart';
import 'package:rv_astro_vastu/features/festivals/guide/domain/puja_timing.dart';
import 'package:rv_astro_vastu/features/festivals/guide/presentation/puja_guide_providers.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/day_divisions.dart';

/// A 12-hour day and a 12-hour night, so a night muhurta is 48 minutes.
final _sun = SunTimes(
  sunrise: DateTime.utc(2026, 11, 8, 6),
  sunset: DateTime.utc(2026, 11, 8, 18),
  nextSunrise: DateTime.utc(2026, 11, 9, 6),
);

DateTime _at(int day, int h, [int m = 0]) => DateTime.utc(2026, 11, day, h, m);

void main() {
  test('each observance gets its traditional puja time', () {
    expect(pujaTimeRuleFor(ObservanceId.diwali), PujaTimeRule.pradosh);
    expect(pujaTimeRuleFor(ObservanceId.mahaShivaratri), PujaTimeRule.nishita);
    expect(pujaTimeRuleFor(ObservanceId.janmashtami), PujaTimeRule.nishita);
    expect(pujaTimeRuleFor(ObservanceId.karvaChauth), PujaTimeRule.moonrise);
    expect(pujaTimeRuleFor(ObservanceId.ganeshChaturthi), PujaTimeRule.midday);
    expect(pujaTimeRuleFor(ObservanceId.ramNavami), PujaTimeRule.midday);
    expect(pujaTimeRuleFor(ObservanceId.ekadashi), PujaTimeRule.morning);
  });

  test('windows follow the day and night muhurtas', () {
    final morning = pujaWindow(PujaTimeRule.morning, _sun)!;
    expect((morning.start, morning.end), (_at(8, 6), _at(8, 8, 24)));

    final midday = pujaWindow(PujaTimeRule.midday, _sun)!;
    expect((midday.start, midday.end), (_at(8, 10, 48), _at(8, 13, 12)));

    final pradosh = pujaWindow(PujaTimeRule.pradosh, _sun)!;
    expect((pradosh.start, pradosh.end), (_at(8, 18), _at(8, 20, 24)));

    final nishita = pujaWindow(PujaTimeRule.nishita, _sun)!;
    expect((nishita.start, nishita.end), (_at(8, 23, 36), _at(9, 0, 24)));

    expect(pujaWindow(PujaTimeRule.moonrise, _sun), isNull);
  });

  test('Rahu Kaal uses the weekday eighth of the day', () {
    // Monday: the second eighth.
    final monday = rahuKaalOf(DayDivisions.calculate(_sun, DateTime.monday));
    expect((monday.start, monday.end), (_at(8, 7, 30), _at(8, 9)));

    // Sunday: the last eighth.
    final sunday = rahuKaalOf(DayDivisions.calculate(_sun, DateTime.sunday));
    expect((sunday.start, sunday.end), (_at(8, 16, 30), _at(8, 18)));
  });

  test('clashes list the periods to avoid inside the puja window', () {
    final day = DayDivisions.calculate(_sun, DateTime.monday);
    final timing = PujaTiming(
      rule: PujaTimeRule.morning,
      timezone: 'UTC',
      window: pujaWindow(PujaTimeRule.morning, _sun),
      avoid: periodsToAvoid(day),
    );
    // Monday Rahu Kaal (7:30–9:00) overlaps the morning window.
    expect(timing.clashes, contains('rahuKaal'));

    final evening = PujaTiming(
      rule: PujaTimeRule.pradosh,
      timezone: 'UTC',
      window: pujaWindow(PujaTimeRule.pradosh, _sun),
      avoid: periodsToAvoid(day),
    );
    expect(evening.clashes, isEmpty);
  });
}
