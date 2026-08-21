import '../../domain/models/kundali_input.dart';
import '../../domain/entities/kundali.dart';
import '../../domain/entities/planet_position.dart';
import '../repositories/astrology_repository.dart';

class MockAstrologyRepository implements AstrologyRepository {
  @override
  Future<Kundali> calculateKundali(KundaliInput input) async {
    return Kundali(
      ayanamsa: 23.85,
      ascendant: 'Aries',
      ascendantDegree: 12.5,
      moonSign: 'Taurus',
      sunSign: 'Capricorn',
      nakshatra: 'Rohini',
      nakshatraPada: 2,
      planets: const [
        PlanetPosition(
          planet: 'Sun',
          sign: 'Capricorn',
          house: 10,
          degree: 15.2,
        ),
        PlanetPosition(planet: 'Moon', sign: 'Taurus', house: 2, degree: 18.4),
        PlanetPosition(planet: 'Mars', sign: 'Gemini', house: 3, degree: 7.8),
        PlanetPosition(
          planet: 'Mercury',
          sign: 'Capricorn',
          house: 10,
          degree: 22.1,
        ),
        PlanetPosition(
          planet: 'Jupiter',
          sign: 'Pisces',
          house: 12,
          degree: 11.3,
        ),
        PlanetPosition(
          planet: 'Venus',
          sign: 'Aquarius',
          house: 11,
          degree: 4.6,
        ),
        PlanetPosition(planet: 'Saturn', sign: 'Libra', house: 7, degree: 28.7),
        PlanetPosition(planet: 'Rahu', sign: 'Scorpio', house: 8, degree: 9.4),
        PlanetPosition(planet: 'Ketu', sign: 'Taurus', house: 2, degree: 9.4),
      ],
      rashiChart: null,
    );
  }
}
