import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/core/astro/swiss_eph_loader.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/kundali.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/planet_position.dart';
import 'package:rv_astro_vastu/features/varshphal/solar_return.dart';
import 'package:rv_astro_vastu/features/varshphal/varshphal.dart';
import 'package:swisseph/swisseph.dart';

PlanetPosition _p(String planet, String sign) => PlanetPosition(
  planet: planet,
  sign: sign,
  house: 1,
  longitude: 0,
  degree: 0,
  retrograde: false,
);

void main() {
  test('Muntha moves one sign a year from the birth Lagna', () {
    expect(munthaSignIndex(4, 0), 4);
    expect(munthaSignIndex(4, 30), 10); // Leo + 30 → Aquarius
    expect(munthaSignIndex(11, 1), 0);
  });

  test('Muntha tone by house', () {
    expect([for (var h = 1; h <= 12; h++) munthaTone(h).name], [
      'good', 'good', 'good', 'care', 'good', 'care', //
      'care', 'care', 'excellent', 'excellent', 'excellent', 'care',
    ]);
  });

  test('years completed follow the calendar birthday', () {
    final dob = DateTime(1990, 8, 15);
    expect(completedYearsOn(dob, DateTime(2026, 8, 14)), 35);
    expect(completedYearsOn(dob, DateTime(2026, 8, 15)), 36);
    expect(completedYearsOn(dob, DateTime(1990, 8, 15)), 0);
  });

  test('year chart houses, Muntha and lords', () {
    final v = Varshphal(
      completedYears: 30,
      praveshUtc: DateTime.utc(2020, 8, 15),
      praveshLocal: DateTime(2020, 8, 15),
      natalLagna: 4, // Leo
      chart: Kundali(
        ascendant: 'Taurus',
        ayanamsa: 24,
        ascendantDegree: 5,
        moonLongitude: 0,
        moonSign: 'Aries',
        sunSign: 'Cancer',
        nakshatra: 'Ashwini',
        nakshatraPada: 1,
        planets: [_p('Sun', 'Cancer'), _p('Saturn', 'Aries')],
      ),
    );
    expect(v.lagnaSign, 1);
    expect(v.munthaSign, 10); // Aquarius
    expect(v.munthaHouse, 10);
    expect(v.tone, MunthaTone.excellent);
    expect(v.lagnaLord, 'Venus');
    expect(v.munthaLord, 'Saturn');
    expect(v.placements, [('Sun', 'Cancer', 3), ('Saturn', 'Aries', 12)]);
  });

  test('solar return puts the Sun back on its birth longitude', () async {
    const natalSun = 118.25;
    final moment = await SwissSolarReturnFinder().find(
      natalSun,
      DateTime.utc(2026, 8, 1),
    );
    final swe = await loadSwissEph();
    try {
      swe.setSidMode(seSidmLahiri);
      final jd =
          2440587.5 + moment.millisecondsSinceEpoch / Duration.millisecondsPerDay;
      final lon = swe.calcUt(jd, seSun, seFlgSwiEph | seFlgSidereal).longitude;
      expect(lon, closeTo(natalSun, 1e-3));
      expect(moment.year, 2026);
      expect(moment.month, anyOf(7, 8));
    } finally {
      swe.close();
    }
  });
}
