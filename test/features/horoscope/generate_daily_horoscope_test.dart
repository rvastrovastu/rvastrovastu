import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_period.dart';
import 'package:rv_astro_vastu/features/horoscope/domain/entities/daily_horoscope.dart';
import 'package:rv_astro_vastu/features/horoscope/domain/usecases/generate_daily_horoscope.dart';
import 'package:rv_astro_vastu/features/your_day/domain/day_strength.dart';

void main() {
  final date = DateTime(2026, 10, 23);

  DashaPeriod dasha(DashaPlanet planet) => DashaPeriod(
    planet: planet,
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2027, 1, 1),
  );

  // Birth Moon at 0° sidereal: Ashwini nakshatra, Aries Moon sign.
  DailyHoroscope reading(double transitMoon) => GenerateDailyHoroscope().call(
    natalMoonLongitude: 0,
    transitMoonLongitude: transitMoon,
    mahadasha: dasha(DashaPlanet.saturn),
    antardasha: dasha(DashaPlanet.mercury),
    date: date,
  );

  Map<HoroscopeArea, Outlook> outlooks(DailyHoroscope h) => {
    for (final a in h.areas) a.area: a.outlook,
  };

  test('covers career, money and love, with the dasha', () {
    final h = reading(13.5);
    expect(h.areas.map((a) => a.area), HoroscopeArea.values);
    expect(h.mahadasha, 'Saturn');
    expect(h.antardasha, 'Mercury');
    expect(h.date, date);
  });

  test('Sampat Tara lifts money; the 1st house favours love', () {
    // Bharani, still in Aries: Sampat Tara, Moon in the 1st.
    final h = reading(13.5);
    expect(h.tara, Tara.sampat);
    expect(h.chandraHouse, 1);
    expect(h.headlineKey, 'sampat');
    expect(outlooks(h), {
      HoroscopeArea.career: Outlook.steady,
      HoroscopeArea.money: Outlook.good,
      HoroscopeArea.love: Outlook.good,
    });
  });

  test('Vipat Tara hurts money and holds the rest back', () {
    // Krittika in Aries: Vipat Tara, Moon in the 1st.
    final h = reading(27);
    expect(h.tara, Tara.vipat);
    expect(outlooks(h), {
      HoroscopeArea.career: Outlook.steady,
      HoroscopeArea.money: Outlook.careful,
      HoroscopeArea.love: Outlook.steady,
    });
  });

  test('Chandrashtama makes every area careful', () {
    // Anuradha in Scorpio: 8th from an Aries Moon, though Mitra Tara.
    final h = reading(215);
    expect(h.tara, Tara.mitra);
    expect(h.isChandrashtama, isTrue);
    expect(h.headlineKey, 'chandrashtama');
    expect(h.verdict, DayVerdict.caution);
    expect(outlooks(h).values, everyElement(Outlook.careful));
  });

  test('a good house with a good Tara is good all round', () {
    // Shatabhisha in Aquarius: Sadhaka Tara, Moon in the 11th.
    final h = reading(310);
    expect(h.tara, Tara.sadhaka);
    expect(h.chandraHouse, 11);
    expect(outlooks(h).values, everyElement(Outlook.good));
  });

  test('the reading changes as the Moon moves', () {
    final days = {
      for (var lon = 0.0; lon < 360; lon += 13.0)
        '${reading(lon).headlineKey} ${outlooks(reading(lon)).values}',
    };
    expect(days.length, greaterThan(10));
  });

  test('every house has an effect for each area', () {
    for (var house = 1; house <= 12; house++) {
      expect(GenerateDailyHoroscope.houseEffects[house], hasLength(3));
    }
  });

  test('missing dasha reads Unknown', () {
    final h = GenerateDailyHoroscope().call(
      natalMoonLongitude: 0,
      transitMoonLongitude: 100,
      mahadasha: null,
      antardasha: null,
      date: date,
    );
    expect(h.mahadasha, 'Unknown');
  });
}
