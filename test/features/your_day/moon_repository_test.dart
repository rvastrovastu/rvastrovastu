import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/your_day/data/swiss_ephemeris_moon_repository.dart';
import 'package:rv_astro_vastu/features/your_day/domain/day_strength.dart';

void main() {
  test('Moon at 00:00 UTC on 20 October 2026', () async {
    final moon = await SwissEphemerisMoonRepository().moonAt(
      DateTime.utc(2026, 10, 20),
    );

    // Swiss Ephemeris (Lahiri): 286.96°, Shravana in Capricorn.
    expect(moon.longitude, closeTo(286.96, 0.01));
    expect(nakshatraNames[nakshatraIndexOf(moon.longitude)], 'Shravana');
    expect(signIndexOf(moon.longitude), 9);

    // Enters Dhanishtha at 12:32 UTC and Aquarius at 01:30 UTC next day.
    expect(
      moon.nakshatraEndsUtc.difference(DateTime.utc(2026, 10, 20, 12, 32)).abs(),
      lessThan(const Duration(minutes: 2)),
    );
    expect(
      moon.signEndsUtc.difference(DateTime.utc(2026, 10, 21, 1, 30)).abs(),
      lessThan(const Duration(minutes: 2)),
    );
  });
}
