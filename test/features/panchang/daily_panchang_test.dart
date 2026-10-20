import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'package:rv_astro_vastu/features/panchang/data/repositories/swiss_ephemeris_daily_panchang_repository.dart';

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });
  group('Swiss Ephemeris Daily Panchang', () {
    test('calculates Panchang for Dallas', () async {
      final repository = SwissEphemerisDailyPanchangRepository();

      final result = await repository.calculate(
        date: DateTime(2026, 8, 29),
        latitude: 32.95,
        longitude: -96.80,
        timezone: 'America/Chicago',
      );

      expect(result.date.year, 2026);
      expect(result.date.month, 8);
      expect(result.date.day, 29);

      // These values are the Panchang elements active at
      // local sunrise on 2026-08-29 in Dallas.
      expect(result.tithi, 'Krishna Dwitiya');
      expect(result.nakshatra, 'Purva Bhadrapada');
      expect(result.yoga, 'Dhriti');

      expect(result.sunrise, '06:59 AM');
      expect(result.sunset, '07:55 PM');
      expect(result.rahuKaal, '10:13 AM – 11:50 AM');
      expect(result.muhurat, '01:01 PM – 01:53 PM');
    });

    test('calculates Panchang for Delhi', () async {
      final repository = SwissEphemerisDailyPanchangRepository();

      final result = await repository.calculate(
        date: DateTime(2026, 8, 29),
        latitude: 28.6139,
        longitude: 77.2090,
        timezone: 'Asia/Kolkata',
      );

      expect(result.date.year, 2026);
      expect(result.date.month, 8);
      expect(result.date.day, 29);

      // These values are the Panchang elements active at
      // local sunrise on 2026-08-29 in Delhi.
      expect(result.tithi, 'Krishna Pratipada');
      expect(result.nakshatra, 'Purva Bhadrapada');
      expect(result.yoga, 'Sukarma');

      expect(result.sunrise, '05:57 AM');
      expect(result.sunset, '06:46 PM');
      expect(result.rahuKaal, '09:09 AM – 10:45 AM');
      expect(result.muhurat, '11:56 AM – 12:47 PM');
    });
  });
}
