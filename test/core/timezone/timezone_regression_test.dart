import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('IANA timezone DST regression', () {
    test('Dallas uses CDT in summer', () {
      final location = tz.getLocation('America/Chicago');

      final local = tz.TZDateTime(location, 2026, 9, 2, 12);

      expect(local.timeZoneOffset, const Duration(hours: -5));
    });

    test('Dallas uses CST in winter', () {
      final location = tz.getLocation('America/Chicago');

      final local = tz.TZDateTime(location, 2026, 1, 15, 12);

      expect(local.timeZoneOffset, const Duration(hours: -6));
    });

    test('San Francisco uses PDT in summer', () {
      final location = tz.getLocation('America/Los_Angeles');

      final local = tz.TZDateTime(location, 2026, 9, 2, 12);

      expect(local.timeZoneOffset, const Duration(hours: -7));
    });

    test('San Francisco uses PST in winter', () {
      final location = tz.getLocation('America/Los_Angeles');

      final local = tz.TZDateTime(location, 2026, 1, 15, 12);

      expect(local.timeZoneOffset, const Duration(hours: -8));
    });

    test('New York uses EDT in summer', () {
      final location = tz.getLocation('America/New_York');

      final local = tz.TZDateTime(location, 2026, 9, 2, 12);

      expect(local.timeZoneOffset, const Duration(hours: -4));
    });

    test('Denver uses MDT in summer', () {
      final location = tz.getLocation('America/Denver');

      final local = tz.TZDateTime(location, 2026, 9, 2, 12);

      expect(local.timeZoneOffset, const Duration(hours: -6));
    });

    test('Delhi remains IST without DST', () {
      final location = tz.getLocation('Asia/Kolkata');

      final summer = tz.TZDateTime(location, 2026, 9, 2, 12);

      final winter = tz.TZDateTime(location, 2026, 1, 15, 12);

      expect(summer.timeZoneOffset, const Duration(hours: 5, minutes: 30));

      expect(winter.timeZoneOffset, const Duration(hours: 5, minutes: 30));
    });

    test('UTC conversion preserves the instant', () {
      final location = tz.getLocation('America/Chicago');

      final local = tz.TZDateTime(location, 2026, 9, 2, 12);

      final utc = local.toUtc();

      expect(utc.hour, 17);
      expect(utc.minute, 0);
    });
  });
}
