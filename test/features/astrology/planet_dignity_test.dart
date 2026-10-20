import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/planet_dignity.dart';

void main() {
  test('exaltation and debilitation', () {
    expect(planetDignity('Sun', 'Aries'), PlanetDignity.exalted);
    expect(planetDignity('Sun', 'Libra'), PlanetDignity.debilitated);
    expect(planetDignity('Saturn', 'Libra'), PlanetDignity.exalted);
    expect(planetDignity('Saturn', 'Aries'), PlanetDignity.debilitated);
    expect(planetDignity('Jupiter', 'Capricorn'), PlanetDignity.debilitated);
  });

  test('own signs', () {
    expect(planetDignity('Mars', 'Scorpio'), PlanetDignity.own);
    expect(planetDignity('Moon', 'Cancer'), PlanetDignity.own);
    expect(planetDignity('Venus', 'Libra'), PlanetDignity.own);
  });

  test('exaltation wins over own sign', () {
    expect(planetDignity('Mercury', 'Virgo'), PlanetDignity.exalted);
  });

  test('case-insensitive planet names', () {
    expect(planetDignity('SUN', 'Aries'), PlanetDignity.exalted);
  });

  test('nodes and unknown input are neutral', () {
    expect(planetDignity('Rahu', 'Taurus'), PlanetDignity.neutral);
    expect(planetDignity('Ketu', 'Scorpio'), PlanetDignity.neutral);
    expect(planetDignity('Sun', 'Nowhere'), PlanetDignity.neutral);
    expect(planetDignity('Venus', 'Gemini'), PlanetDignity.neutral);
  });
}
