import 'package:rv_astro_vastu/features/astrology/domain/entities/kundali.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/planet_position.dart';
import 'package:rv_astro_vastu/features/dosha/domain/entities/sade_sati.dart';
import 'package:rv_astro_vastu/features/dosha/domain/entities/zodiac_signs.dart';

/// Builds a whole-sign Kundali from sidereal longitudes.
///
/// [longitudes] must contain Sun..Saturn and Rahu; Ketu is derived.
Kundali kundaliFrom({
  required double ascendant,
  required Map<String, double> longitudes,
}) {
  final all = Map<String, double>.of(longitudes);
  all.putIfAbsent('Ketu', () => (all['Rahu']! + 180) % 360);

  final ascIndex = (ascendant / 30).floor();

  PlanetPosition position(String name, double longitude) {
    final signIndex = (longitude / 30).floor() % 12;
    return PlanetPosition(
      planet: name,
      sign: zodiacSigns[signIndex],
      house: houseFrom(ascIndex, signIndex),
      longitude: longitude,
      degree: longitude % 30,
    );
  }

  final planets = [
    for (final entry in all.entries) position(entry.key, entry.value),
  ];
  final moon = planets.firstWhere((p) => p.planet == 'Moon');
  final sun = planets.firstWhere((p) => p.planet == 'Sun');

  return Kundali(
    ascendant: zodiacSigns[ascIndex],
    ayanamsa: 24.1,
    ascendantDegree: ascendant % 30,
    moonLongitude: moon.longitude,
    moonSign: moon.sign,
    sunSign: sun.sign,
    nakshatra: 'Rohini',
    nakshatraPada: 1,
    planets: planets,
  );
}

/// Sign start longitude (0° of the sign) plus [degree].
double inSign(String sign, [double degree = 10]) =>
    zodiacSignIndex(sign) * 30 + degree;

/// Lahiri sidereal Saturn sign periods 2015–2042, produced by the same
/// 5-day scan + bisection the Swiss Ephemeris repository uses (checked with
/// pyswisseph). Dates are rounded to the day.
final List<SaturnSignPeriod> saturnPeriods = [
  _p('Scorpio', '2015-01-01', '2017-01-26'),
  _p('Sagittarius', '2017-01-26', '2017-06-20'),
  _p('Scorpio', '2017-06-20', '2017-10-26'),
  _p('Sagittarius', '2017-10-26', '2020-01-24'),
  _p('Capricorn', '2020-01-24', '2022-04-29'),
  _p('Aquarius', '2022-04-29', '2022-07-12'),
  _p('Capricorn', '2022-07-12', '2023-01-17'),
  _p('Aquarius', '2023-01-17', '2025-03-29'),
  _p('Pisces', '2025-03-29', '2027-06-03'),
  _p('Aries', '2027-06-03', '2027-10-20'),
  _p('Pisces', '2027-10-20', '2028-02-23'),
  _p('Aries', '2028-02-23', '2029-08-08'),
  _p('Taurus', '2029-08-08', '2029-10-05'),
  _p('Aries', '2029-10-05', '2030-04-17'),
  _p('Taurus', '2030-04-17', '2032-05-30'),
  _p('Gemini', '2032-05-30', '2034-07-12'),
  _p('Cancer', '2034-07-12', '2036-08-27'),
  _p('Leo', '2036-08-27', '2038-10-22'),
  _p('Virgo', '2038-10-22', '2039-04-05'),
  _p('Leo', '2039-04-05', '2039-07-12'),
  _p('Virgo', '2039-07-12', '2041-01-27'),
  _p('Libra', '2041-01-27', '2041-02-06'),
  _p('Virgo', '2041-02-06', '2041-09-26'),
  _p('Libra', '2041-09-26', '2042-01-01'),
];

SaturnSignPeriod _p(String sign, String start, String end) => SaturnSignPeriod(
  signIndex: zodiacSignIndex(sign),
  start: DateTime.parse('${start}T00:00:00Z'),
  end: DateTime.parse('${end}T00:00:00Z'),
);
