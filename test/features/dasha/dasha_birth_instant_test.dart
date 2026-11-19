import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/dasha/domain/dasha_birth_instant.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_birth_data.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_period.dart';
import 'package:rv_astro_vastu/features/dasha/domain/usecases/calculate_current_dasha.dart';
import 'package:rv_astro_vastu/features/dasha/domain/usecases/calculate_vimshottari_dasha.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('birthInstant', () {
    test('reads the birth time in the birth time zone', () {
      final at = birthInstant(DateTime(1950, 9, 17), '11:00', 'Asia/Kolkata');
      expect(at.toUtc(), DateTime.utc(1950, 9, 17, 5, 30));
    });

    test('accepts older AM/PM values', () {
      final at = birthInstant(
        DateTime(1990, 1, 1),
        '11:15 PM',
        'Asia/Kolkata',
      );
      expect(at.toUtc(), DateTime.utc(1990, 1, 1, 17, 45));
    });

    test('falls back to device time when the zone is unknown', () {
      final at = birthInstant(DateTime(1990, 1, 1), '06:30', 'Not/AZone');
      expect(at, DateTime(1990, 1, 1, 6, 30));
    });
  });

  // Reference chart: 17 Sep 1950, 11:00 IST, Vadnagar. Sidereal (Lahiri)
  // Moon 218.81° in Anuradha, so life starts in Saturn Mahadasha; published
  // Vimshottari tables give Moon 2011-2021 and Mars 2021-2028.
  test('matches a published Vimshottari timeline', () {
    final birth = DashaBirthData(
      birthDate: birthInstant(DateTime(1950, 9, 17), '11:00', 'Asia/Kolkata'),
      moonLongitude: 218.8079,
    );
    final timeline = CalculateVimshottariDasha()(birthData: birth);

    expect(timeline.periods.first.planet, DashaPlanet.saturn);
    DashaPlanet? at(DateTime date) => CalculateCurrentDasha()(
      timeline: timeline,
      date: date,
    ).mahadasha?.planet;
    expect(at(DateTime(2015, 6, 1)), DashaPlanet.moon);
    expect(at(DateTime(2025, 6, 1)), DashaPlanet.mars);
    expect(at(DateTime(2030, 6, 1)), DashaPlanet.rahu);
  });
}
