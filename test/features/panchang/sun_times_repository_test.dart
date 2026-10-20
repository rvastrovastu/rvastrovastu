import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/panchang/data/repositories/swiss_ephemeris_sun_times_repository.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/day_divisions.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('New Delhi, Monday 19 October 2026', () async {
    final sun = await SwissEphemerisSunTimesRepository().sunTimes(
      date: DateTime(2026, 10, 19),
      latitude: 28.6139,
      longitude: 77.209,
      timezone: 'Asia/Kolkata',
    );
    expect(sun, isNotNull);

    final delhi = tz.getLocation('Asia/Kolkata');
    String hm(DateTime t) {
      final l = tz.TZDateTime.from(t, delhi);
      return '${l.day} ${l.hour}:${l.minute.toString().padLeft(2, '0')}';
    }

    // Swiss Ephemeris: 06:24, 17:47 and 06:24 next morning (IST).
    expect(hm(sun!.sunrise), '19 6:24');
    expect(hm(sun.sunset), '19 17:47');
    expect(hm(sun.nextSunrise), '20 6:24');

    final d = DayDivisions.calculate(sun, DateTime.monday);
    expect(d.dayChoghadiya.first.value, Choghadiya.amrit);
    expect(hm(d.yamaganda.start), '19 10:40');
    expect(hm(d.gulika.start), '19 13:31');
  });

  test('no Vedic day where the Sun stays up (Svalbard in June)', () async {
    final sun = await SwissEphemerisSunTimesRepository().sunTimes(
      date: DateTime(2026, 6, 21),
      latitude: 78.22,
      longitude: 15.65,
      timezone: 'Europe/Berlin',
    );
    expect(sun, isNull);
  });
}
