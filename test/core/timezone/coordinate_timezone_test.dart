import 'package:flutter_test/flutter_test.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart';

void main() {
  group('Coordinate to IANA timezone', () {
    test('San Francisco coordinates resolve to Los Angeles timezone', () {
      expect(
        latLngToTimezoneString(37.785834, -122.406417),
        'America/Los_Angeles',
      );
    });

    test('Dallas coordinates resolve to Chicago timezone', () {
      expect(latLngToTimezoneString(32.7767, -96.7970), 'America/Chicago');
    });

    test('Prosper coordinates resolve to Chicago timezone', () {
      expect(latLngToTimezoneString(33.2362, -96.8011), 'America/Chicago');
    });

    test('Delhi coordinates resolve to Kolkata timezone', () {
      expect(latLngToTimezoneString(28.6139, 77.2090), 'Asia/Kolkata');
    });
  });
}
