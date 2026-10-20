import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/astrology/domain/entities/kundali.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/planet_position.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_period.dart';
import 'package:rv_astro_vastu/features/horoscope/domain/usecases/generate_daily_horoscope.dart';

void main() {
  group('GenerateDailyHoroscope', () {
    final date = DateTime(2026, 9, 2);

    DashaPeriod dasha(DashaPlanet planet) {
      return DashaPeriod(
        planet: planet,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2027, 1, 1),
      );
    }

    Kundali kundali({
      List<PlanetPosition> planets = const [],
      String moonSign = 'Scorpio',
      String nakshatra = 'Anuradha',
    }) {
      return Kundali(
        ascendant: 'Leo',
        ayanamsa: 24.0,
        ascendantDegree: 12.0,
        moonLongitude: 220.0,
        moonSign: moonSign,
        sunSign: 'Leo',
        nakshatra: nakshatra,
        nakshatraPada: 1,
        planets: planets,
      );
    }

    test('returns all three horoscope sections', () {
      final result = GenerateDailyHoroscope().call(
        kundali: kundali(),
        mahadasha: dasha(DashaPlanet.mercury),
        antardasha: dasha(DashaPlanet.venus),
        date: date,
      );

      expect(result.date, date);
      expect(result.career, isNotEmpty);
      expect(result.finance, isNotEmpty);
      expect(result.relationships, isNotEmpty);
      expect(result.insights, hasLength(3));
    });

    test('uses Mercury in 10th house for career guidance', () {
      final result = GenerateDailyHoroscope().call(
        kundali: kundali(
          planets: [
            PlanetPosition(
              planet: 'Mercury',
              sign: 'Taurus',
              house: 10,
              longitude: 45.0,
              degree: 15.0,
            ),
          ],
        ),
        mahadasha: dasha(DashaPlanet.mercury),
        antardasha: dasha(DashaPlanet.venus),
        date: date,
      );

      expect(result.career, contains('communication'));
      expect(result.career, contains('Mercury'));
    });

    test('uses Jupiter in 11th house for finance guidance', () {
      final result = GenerateDailyHoroscope().call(
        kundali: kundali(
          planets: [
            PlanetPosition(
              planet: 'Jupiter',
              sign: 'Gemini',
              house: 11,
              longitude: 75.0,
              degree: 15.0,
            ),
          ],
        ),
        mahadasha: dasha(DashaPlanet.jupiter),
        antardasha: dasha(DashaPlanet.venus),
        date: date,
      );

      expect(result.finance, contains('Financial prospects'));
    });

    test('uses Venus in 7th house for relationship guidance', () {
      final result = GenerateDailyHoroscope().call(
        kundali: kundali(
          planets: [
            PlanetPosition(
              planet: 'Venus',
              sign: 'Libra',
              house: 7,
              longitude: 195.0,
              degree: 15.0,
            ),
          ],
        ),
        mahadasha: dasha(DashaPlanet.venus),
        antardasha: dasha(DashaPlanet.moon),
        date: date,
      );

      expect(result.relationships, contains('Warmth'));
      expect(result.relationships, contains('relationships'));
    });

    test('uses retrograde condition for career review guidance', () {
      final result = GenerateDailyHoroscope().call(
        kundali: kundali(
          planets: [
            PlanetPosition(
              planet: 'Mars',
              sign: 'Cancer',
              house: 3,
              longitude: 105.0,
              degree: 15.0,
              retrograde: true,
            ),
          ],
        ),
        mahadasha: dasha(DashaPlanet.saturn),
        antardasha: dasha(DashaPlanet.mercury),
        date: date,
      );

      expect(result.career, contains('Review ongoing work'));
    });
  });
}
