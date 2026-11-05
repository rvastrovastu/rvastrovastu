import '../../../dasha/domain/entities/dasha_period.dart';
import '../../../your_day/domain/day_strength.dart';
import '../entities/daily_horoscope.dart';

/// Builds today's reading from the transiting Moon.
///
/// Each area starts from the classical result of the Moon's transit
/// through each house from the natal Moon (Chandra Gochara): good in the
/// 3rd, 6th, 7th, 10th and 11th, hard in the 8th (Chandrashtama), and so
/// on, area by area. Tara Bala then adjusts it: Sampat helps money,
/// Sadhaka career, Mitra and Param Mitra relationships; Vipat, Pratyari
/// and Vadha each hurt one area and hold the others back from "good".
class GenerateDailyHoroscope {
  /// (career, money, love) for the Moon in each house from the natal Moon:
  /// 1 good, 0 neutral, -1 hard.
  static const houseEffects = <int, List<int>>{
    1: [0, 0, 1],
    2: [0, -1, 0],
    3: [1, 1, 1],
    4: [0, 0, -1],
    5: [-1, -1, 0],
    6: [1, 1, 0],
    7: [1, 1, 1],
    8: [-1, -1, -1],
    9: [-1, -1, 0],
    10: [1, 1, 0],
    11: [1, 1, 1],
    12: [0, -1, 0],
  };

  DailyHoroscope call({
    required double natalMoonLongitude,
    required double transitMoonLongitude,
    required DashaPeriod? mahadasha,
    required DashaPeriod? antardasha,
    required DateTime date,
  }) {
    final strength = DayStrength.fromLongitudes(
      natalMoon: natalMoonLongitude,
      transitMoon: transitMoonLongitude,
    );

    return DailyHoroscope(
      date: date,
      strength: strength,
      mahadasha: mahadasha?.planet.name ?? 'Unknown',
      antardasha: antardasha?.planet.name ?? 'Unknown',
      areas: [
        for (final area in HoroscopeArea.values)
          AreaReading(
            area: area,
            outlook: outlookFor(area, strength),
            chandraHouse: strength.chandraHouse,
          ),
      ],
    );
  }

  static Outlook outlookFor(HoroscopeArea area, DayStrength strength) {
    if (strength.isChandrashtama) return Outlook.careful;

    var score = houseEffects[strength.chandraHouse]![area.index];
    final tara = strength.tara;

    // The area each Tara speaks to most.
    final focus = switch (tara) {
      Tara.sampat || Tara.vipat => HoroscopeArea.money,
      Tara.sadhaka || Tara.vadha => HoroscopeArea.career,
      Tara.mitra || Tara.paramaMitra || Tara.pratyari => HoroscopeArea.love,
      Tara.janma || Tara.kshema => null,
    };

    if (tara.strength == Strength.good && area == focus) {
      score += 1;
    } else if (tara.strength == Strength.bad) {
      if (area == focus) {
        score -= 1;
      } else if (score > 0) {
        score = 0;
      }
    }

    if (score > 0) return Outlook.good;
    if (score < 0) return Outlook.careful;
    return Outlook.steady;
  }
}
