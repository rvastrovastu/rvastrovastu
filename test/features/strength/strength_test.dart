import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/kundali.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/planet_position.dart';
import 'package:rv_astro_vastu/features/dosha/domain/entities/zodiac_signs.dart';
import 'package:rv_astro_vastu/features/strength/ashtakavarga.dart';
import 'package:rv_astro_vastu/features/strength/planet_strength.dart';

PlanetPosition _p(String planet, double lon, {bool retro = false}) =>
    PlanetPosition(
      planet: planet,
      sign: zodiacSigns[lon ~/ 30],
      house: 1,
      longitude: lon,
      degree: lon % 30,
      retrograde: retro,
    );

Kundali _kundali({String ascendant = 'Leo', double ascDegree = 12}) => Kundali(
  ascendant: ascendant,
  ayanamsa: 24,
  ascendantDegree: ascDegree,
  moonLongitude: 200,
  moonSign: 'Libra',
  sunSign: 'Aries',
  nakshatra: 'Swati',
  nakshatraPada: 2,
  planets: [
    _p('Sun', 10), // deep exaltation
    _p('Moon', 200),
    _p('Mars', 118), // deep debilitation in Cancer
    _p('Mercury', 25),
    _p('Jupiter', 250),
    _p('Venus', 340),
    _p('Saturn', 300, retro: true),
    _p('Rahu', 60),
    _p('Ketu', 240),
  ],
);

void main() {
  group('Ashtakavarga', () {
    test('each planet has its classical bindu total, Sarva totals 337', () {
      final av = calculateAshtakavarga(_kundali());
      int sum(List<int> l) => l.fold(0, (a, b) => a + b);
      expect({for (final p in ashtakavargaPlanets) p: sum(av.bhinna[p]!)}, {
        'Sun': 48,
        'Moon': 49,
        'Mars': 39,
        'Mercury': 54,
        'Jupiter': 56,
        'Venus': 52,
        'Saturn': 39,
      });
      expect(sum(av.sarva), 337);
    });

    test('Sarva is the sum of the Bhinna tables, houses count from Lagna', () {
      final av = calculateAshtakavarga(_kundali());
      for (var s = 0; s < 12; s++) {
        expect(
          av.sarva[s],
          ashtakavargaPlanets.fold<int>(0, (a, p) => a + av.bhinna[p]![s]),
        );
        expect(av.bhinna.values.every((l) => l[s] >= 0 && l[s] <= 8), isTrue);
      }
      expect(av.lagnaSign, 4);
      expect(av.houseSarva(1), av.sarva[4]);
      expect(av.houseSarva(9), av.sarva[0]);
    });
  });

  group('Planet strength', () {
    test('sorted strongest first, rupas are virupas / 60', () {
      final list = calculatePlanetStrength(_kundali());
      expect(list, hasLength(7));
      for (var i = 1; i < list.length; i++) {
        expect(list[i - 1].total, greaterThanOrEqualTo(list[i].total));
      }
      for (final s in list) {
        expect(s.rupas, closeTo(s.total / 60, 1e-9));
      }
    });

    test('exaltation, debilitation and retrograde motion', () {
      final byName = {
        for (final s in calculatePlanetStrength(_kundali())) s.planet: s,
      };
      expect(byName['Sun']!.uchcha, closeTo(60, 1e-9));
      expect(byName['Mars']!.uchcha, lessThan(5));
      expect(byName['Saturn']!.chesta, 60);
      expect(byName['Mercury']!.chesta, 30);
      expect(byName['Saturn']!.dignity, 30); // own sign, Capricorn
    });
  });
}
