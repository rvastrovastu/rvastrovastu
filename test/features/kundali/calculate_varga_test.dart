import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/kundali.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/planet_position.dart';
import 'package:rv_astro_vastu/features/kundali/domain/usecases/calculate_navamsa.dart';
import 'package:rv_astro_vastu/features/kundali/domain/usecases/calculate_varga.dart';

const _aries = 0, _taurus = 1, _gemini = 2, _cancer = 3, _leo = 4;
const _virgo = 5, _libra = 6, _scorpio = 7, _sagittarius = 8;
const _capricorn = 9, _aquarius = 10, _pisces = 11;

int _sign(Varga v, double longitude) => CalculateVarga.place(v, longitude).$1;

void main() {
  test('D9 matches the existing Navamsa calculation', () {
    for (var lon = 0.0; lon < 360; lon += 1.7) {
      expect(
        _sign(Varga.d9, lon),
        CalculateNavamsa.navamsaSignIndex(lon),
        reason: '$lon',
      );
    }
  });

  test('Hora: Sun hora is Leo, Moon hora is Cancer', () {
    expect(_sign(Varga.d2, 10), _leo); // Aries (odd), first half
    expect(_sign(Varga.d2, 20), _cancer); // Aries, second half
    expect(_sign(Varga.d2, 40), _cancer); // Taurus (even), first half
    expect(_sign(Varga.d2, 50), _leo);
  });

  test('Drekkana: same sign, 5th, 9th', () {
    expect(_sign(Varga.d3, 35), _taurus);
    expect(_sign(Varga.d3, 45), _virgo);
    expect(_sign(Varga.d3, 55), _capricorn);
  });

  test('Saptamsha and Dashamsha start from the 7th / 9th for even signs', () {
    expect(_sign(Varga.d7, 1), _aries);
    expect(_sign(Varga.d7, 31), _scorpio); // Taurus → 7th is Scorpio
    expect(_sign(Varga.d10, 1), _aries);
    expect(_sign(Varga.d10, 31), _capricorn); // Taurus → 9th is Capricorn
    expect(_sign(Varga.d10, 59), _libra); // last part: Capricorn + 9
  });

  test('Shodashamsha and Vimshamsha start by modality', () {
    expect(_sign(Varga.d16, 30.5), _leo); // Taurus is fixed
    expect(_sign(Varga.d16, 60.5), _sagittarius); // Gemini is dual
    expect(_sign(Varga.d20, 30.5), _sagittarius);
    expect(_sign(Varga.d20, 60.5), _leo);
  });

  test('Chaturvimshamsha, Khavedamsha', () {
    expect(_sign(Varga.d24, 0.5), _leo);
    expect(_sign(Varga.d24, 30.5), _cancer);
    expect(_sign(Varga.d40, 30.2), _libra);
  });

  test('Bhamsha follows the element of the sign', () {
    expect(_sign(Varga.d27, 0.5), _aries);
    expect(_sign(Varga.d27, 30.5), _cancer);
    expect(_sign(Varga.d27, 60.5), _libra);
    expect(_sign(Varga.d27, 90.5), _capricorn);
  });

  test('Trimshamsha uses the unequal Parashari parts', () {
    expect(_sign(Varga.d30, 2), _aries); // Mars
    expect(_sign(Varga.d30, 7), _aquarius); // Saturn
    expect(_sign(Varga.d30, 15), _sagittarius); // Jupiter
    expect(_sign(Varga.d30, 20), _gemini); // Mercury
    expect(_sign(Varga.d30, 29.9), _libra); // Venus
    expect(_sign(Varga.d30, 32), _taurus); // even: Venus
    expect(_sign(Varga.d30, 59.9), _scorpio); // even: Mars
    expect(_sign(Varga.d30, 45), _pisces); // even: Jupiter
  });

  test('Shashtiamsha counts half-degrees from the sign', () {
    expect(_sign(Varga.d60, 0.2), _aries);
    expect(_sign(Varga.d60, 0.7), _taurus);
    expect(_sign(Varga.d60, 29.9), _pisces); // 59 parts on from Aries
  });

  test('the Moon chart puts the Moon sign in the first house', () {
    const kundali = Kundali(
      ascendant: 'Aries',
      ayanamsa: 24,
      ascendantDegree: 10,
      moonLongitude: 125,
      moonSign: 'Leo',
      sunSign: 'Aries',
      nakshatra: 'Magha',
      nakshatraPada: 3,
      planets: [
        PlanetPosition(
          planet: 'Moon',
          sign: 'Leo',
          house: 5,
          longitude: 125,
          degree: 5,
        ),
        PlanetPosition(
          planet: 'Sun',
          sign: 'Aries',
          house: 1,
          longitude: 15,
          degree: 15,
        ),
      ],
    );
    final chart = const CalculateVarga()(kundali, Varga.moon);
    expect(chart.lagnaSign, 'Leo');
    expect(chart.chart.house(1)!.planets.single.planet, 'Moon');
    expect(chart.chart.house(9)!.planets.single.planet, 'Sun');

    final d10 = const CalculateVarga()(kundali, Varga.d10);
    expect(d10.chart.houses, hasLength(12));
  });
}
