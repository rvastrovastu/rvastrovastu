import '../../../your_day/domain/day_strength.dart';

/// The three areas the daily reading covers.
enum HoroscopeArea { career, money, love }

/// How an area looks today.
enum Outlook { good, steady, careful }

/// Today's reading for one area. The line comes from the Moon's house
/// counted from the natal Moon ([chandraHouse]); the [outlook] also weighs
/// Tara Bala.
class AreaReading {
  final HoroscopeArea area;
  final Outlook outlook;
  final int chandraHouse;

  const AreaReading({
    required this.area,
    required this.outlook,
    required this.chandraHouse,
  });
}

/// A short, personal reading for today, built from the transiting Moon
/// against the birth Moon (Tara Bala and Chandra Bala) and the running
/// Vimshottari dasha.
class DailyHoroscope {
  final DateTime date;
  final DayStrength strength;

  /// Running dasha lords, e.g. 'Saturn' and 'Mercury'; 'Unknown' if not
  /// available.
  final String mahadasha;
  final String antardasha;

  /// Career, money and love, in that order.
  final List<AreaReading> areas;

  const DailyHoroscope({
    required this.date,
    required this.strength,
    required this.mahadasha,
    required this.antardasha,
    required this.areas,
  });

  Tara get tara => strength.tara;

  int get chandraHouse => strength.chandraHouse;

  bool get isChandrashtama => strength.isChandrashtama;

  DayVerdict get verdict => strength.verdict;

  /// Key for today's headline: 'chandrashtama' on that day, otherwise the
  /// Tara's name.
  String get headlineKey => isChandrashtama ? 'chandrashtama' : tara.name;

  AreaReading area(HoroscopeArea area) => areas.firstWhere((a) => a.area == area);
}
