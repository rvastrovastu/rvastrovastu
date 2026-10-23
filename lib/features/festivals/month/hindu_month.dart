import '../domain/entities/lunar_calendar_data.dart';
import '../domain/usecases/build_festival_calendar.dart';

/// One day of the Hindu calendar month grid.
class HinduDay {
  final DateTime date;

  /// Udaya tithi (at sunrise), 0–29; null where the Sun doesn't rise.
  final int? tithi;

  /// Amanta month (new moon to new moon) running at sunrise.
  final LunarMonth? month;
  final bool adhik;
  final DateTime? sunrise;
  final DateTime? sunset;

  const HinduDay({
    required this.date,
    this.tithi,
    this.month,
    this.adhik = false,
    this.sunrise,
    this.sunset,
  });

  bool get isShukla => tithi != null && tithi! < 15;

  /// The month name in the Purnimanta reckoning (full moon to full moon,
  /// used in much of North India): the dark half belongs to the next month.
  LunarMonth? get purnimantaMonth {
    final m = month;
    if (m == null || tithi == null || tithi! < 15) return m;
    return LunarMonth.values[(m.index + 1) % 12];
  }

  /// 1–15 within the paksha (15 = Purnima or Amavasya).
  int? get tithiInPaksha => tithi == null ? null : tithi! % 15 + 1;
}

const _tithiNames = [
  'Pratipada', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami', //
  'Shashthi', 'Saptami', 'Ashtami', 'Navami', 'Dashami', 'Ekadashi',
  'Dwadashi', 'Trayodashi', 'Chaturdashi',
];

/// Canonical tithi name for [index] (0–29), as the Panchang uses.
String tithiCanonicalName(int index) {
  if (index == 14) return 'Purnima';
  if (index == 29) return 'Amavasya';
  return index < 15
      ? 'Shukla ${_tithiNames[index]}'
      : 'Krishna ${_tithiNames[index - 15]}';
}

/// Every local day of [year]/[month] from the raw lunar data.
List<HinduDay> buildHinduMonth(LunarCalendarData data, int year, int month) {
  int? tithiAt(DateTime instant) {
    for (final t in data.tithis) {
      if (t.contains(instant)) return t.index;
    }
    return null;
  }

  (LunarMonth, bool)? monthAt(DateTime instant) {
    final moons = data.newMoons;
    for (var i = 0; i < moons.length - 1; i++) {
      if (!instant.isBefore(moons[i].time) &&
          instant.isBefore(moons[i + 1].time)) {
        return (
          LunarMonth.values[(moons[i].sunSignIndex + 1) % 12],
          moons[i].sunSignIndex == moons[i + 1].sunSignIndex,
        );
      }
    }
    return null;
  }

  return [
    for (final day in data.days)
      if (day.date.year == year && day.date.month == month)
        () {
          final at = day.sunrise;
          final m = at == null ? null : monthAt(at);
          return HinduDay(
            date: DateTime(day.date.year, day.date.month, day.date.day),
            tithi: at == null ? null : tithiAt(at),
            month: m?.$1,
            adhik: m?.$2 ?? false,
            sunrise: day.sunrise,
            sunset: day.sunset,
          );
        }(),
  ];
}
