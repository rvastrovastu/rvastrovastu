import '../entities/calendar_observance.dart';
import '../entities/lunar_calendar_data.dart';

/// Amanta lunar months, indexed so that a new moon with the Sun in sidereal
/// sign `s` begins month `(s + 1) % 12` (Sun in Pisces → Chaitra).
enum LunarMonth {
  chaitra,
  vaishakha,
  jyeshtha,
  ashadha,
  shravana,
  bhadrapada,
  ashvin,
  kartika,
  margashirsha,
  pausha,
  magha,
  phalguna,
}

/// The moment of the day at which a festival's tithi is checked.
enum ObservanceTime {
  /// Udaya tithi — the tithi prevailing at sunrise.
  sunrise,

  /// Midday, halfway between sunrise and sunset.
  madhyahna,

  /// Afternoon, 60% of the way from sunrise to sunset.
  aparahna,

  /// Early evening, ~72 minutes after sunset.
  pradosh,

  /// Midnight, halfway between sunset and the next sunrise.
  nishita,

  /// Moonrise.
  moonrise,
}

class _FestivalRule {
  final ObservanceId id;
  final LunarMonth month;
  final int tithi;
  final ObservanceTime time;

  const _FestivalRule(this.id, this.month, this.tithi, this.time);
}

class _RecurringRule {
  final ObservanceId id;
  final Set<int> tithis;
  final ObservanceTime time;

  const _RecurringRule(this.id, this.tithis, this.time);
}

/// Builds festival and vrat dates from [LunarCalendarData].
///
/// Months are amanta (new moon to new moon), so Krishna-paksha festivals
/// use the month that *ends* with the following Amavasya — e.g. Janmashtami
/// is Shravana Krishna Ashtami here (Bhadrapada in the purnimanta system).
///
/// For each tithi, the observance falls on the first day whose check time
/// (see [ObservanceTime]) lies inside the tithi. If none does, it falls back
/// to the sunrise rule, then to the day on which the tithi begins (a kshaya
/// tithi that never touches a sunrise). Festivals are skipped in an Adhik
/// (leap) month, matching standard practice.
///
/// Verified against published 2026 dates for Delhi and Dallas (Diwali 8 Nov,
/// Dussehra 20 Oct, Janmashtami 4 Sep in India / 3 Sep in the US, etc.).
class BuildFestivalCalendar {
  static const Duration _pradoshOffset = Duration(minutes: 72);

  static const List<_FestivalRule> _festivals = [
    _FestivalRule(
      ObservanceId.vasantPanchami,
      LunarMonth.magha,
      4,
      ObservanceTime.sunrise,
    ),
    _FestivalRule(
      ObservanceId.mahaShivaratri,
      LunarMonth.magha,
      28,
      ObservanceTime.nishita,
    ),
    _FestivalRule(
      ObservanceId.holi,
      LunarMonth.phalguna,
      15,
      ObservanceTime.sunrise,
    ),
    _FestivalRule(
      ObservanceId.ugadi,
      LunarMonth.chaitra,
      0,
      ObservanceTime.sunrise,
    ),
    _FestivalRule(
      ObservanceId.ramNavami,
      LunarMonth.chaitra,
      8,
      ObservanceTime.madhyahna,
    ),
    _FestivalRule(
      ObservanceId.hanumanJayanti,
      LunarMonth.chaitra,
      14,
      ObservanceTime.sunrise,
    ),
    _FestivalRule(
      ObservanceId.akshayaTritiya,
      LunarMonth.vaishakha,
      2,
      ObservanceTime.sunrise,
    ),
    _FestivalRule(
      ObservanceId.nirjalaEkadashi,
      LunarMonth.jyeshtha,
      10,
      ObservanceTime.sunrise,
    ),
    _FestivalRule(
      ObservanceId.devshayaniEkadashi,
      LunarMonth.ashadha,
      10,
      ObservanceTime.sunrise,
    ),
    _FestivalRule(
      ObservanceId.guruPurnima,
      LunarMonth.ashadha,
      14,
      ObservanceTime.sunrise,
    ),
    _FestivalRule(
      ObservanceId.rakshaBandhan,
      LunarMonth.shravana,
      14,
      ObservanceTime.sunrise,
    ),
    _FestivalRule(
      ObservanceId.janmashtami,
      LunarMonth.shravana,
      22,
      ObservanceTime.nishita,
    ),
    _FestivalRule(
      ObservanceId.ganeshChaturthi,
      LunarMonth.bhadrapada,
      3,
      ObservanceTime.madhyahna,
    ),
    _FestivalRule(
      ObservanceId.navratri,
      LunarMonth.ashvin,
      0,
      ObservanceTime.sunrise,
    ),
    _FestivalRule(
      ObservanceId.dussehra,
      LunarMonth.ashvin,
      9,
      ObservanceTime.aparahna,
    ),
    _FestivalRule(
      ObservanceId.karvaChauth,
      LunarMonth.ashvin,
      18,
      ObservanceTime.moonrise,
    ),
    _FestivalRule(
      ObservanceId.dhanteras,
      LunarMonth.ashvin,
      27,
      ObservanceTime.pradosh,
    ),
    _FestivalRule(
      ObservanceId.diwali,
      LunarMonth.ashvin,
      29,
      ObservanceTime.pradosh,
    ),
    _FestivalRule(
      ObservanceId.devUthaniEkadashi,
      LunarMonth.kartika,
      10,
      ObservanceTime.sunrise,
    ),
  ];

  static const List<_RecurringRule> _recurring = [
    _RecurringRule(ObservanceId.ekadashi, {10, 25}, ObservanceTime.sunrise),
    _RecurringRule(ObservanceId.purnima, {14}, ObservanceTime.sunrise),
    _RecurringRule(ObservanceId.amavasya, {29}, ObservanceTime.sunrise),
    _RecurringRule(ObservanceId.pradosh, {12, 27}, ObservanceTime.pradosh),
    _RecurringRule(ObservanceId.sankashti, {18}, ObservanceTime.moonrise),
    _RecurringRule(
      ObservanceId.masikShivaratri,
      {28},
      ObservanceTime.nishita,
    ),
  ];

  /// Named Ekadashis replace the generic Ekadashi entry on the same day.
  static const Set<ObservanceId> _namedEkadashis = {
    ObservanceId.nirjalaEkadashi,
    ObservanceId.devshayaniEkadashi,
    ObservanceId.devUthaniEkadashi,
  };

  const BuildFestivalCalendar();

  /// Observances on local dates [fromDate]..[toDate] (inclusive), sorted.
  List<CalendarObservance> call(
    LunarCalendarData data, {
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final from = _dateOnly(fromDate);
    final to = _dateOnly(toDate);
    final newMoons = [...data.newMoons]
      ..sort((a, b) => a.time.compareTo(b.time));

    final results = <CalendarObservance>{};

    for (final segment in data.tithis) {
      final month = _monthAt(newMoons, segment.start);
      if (month == null) continue;

      if (!month.isAdhik) {
        for (final rule in _festivals) {
          if (rule.month == month.month && rule.tithi == segment.index) {
            final date = _observe(data.days, segment, rule.time);
            if (date != null) {
              results.add(
                CalendarObservance(
                  date: date,
                  id: rule.id,
                  tithiIndex: segment.index,
                ),
              );
            }
          }
        }
      }

      for (final rule in _recurring) {
        if (rule.tithis.contains(segment.index)) {
          final date = _observe(data.days, segment, rule.time);
          if (date != null) {
            results.add(
              CalendarObservance(
                date: date,
                id: rule.id,
                tithiIndex: segment.index,
              ),
            );
          }
        }
      }
    }

    for (final sankranti in data.sankrantis) {
      if (sankranti.signIndex == 9) {
        results.add(
          CalendarObservance(
            date: _dateOnly(sankranti.localDate),
            id: ObservanceId.makarSankranti,
          ),
        );
      }
    }

    // Drop generic entries that duplicate a named one on the same day.
    final namedEkadashiDays = {
      for (final o in results)
        if (_namedEkadashis.contains(o.id)) o.date,
    };
    final mahaShivaratriDays = {
      for (final o in results)
        if (o.id == ObservanceId.mahaShivaratri) o.date,
    };
    results.removeWhere(
      (o) =>
          (o.id == ObservanceId.ekadashi &&
              namedEkadashiDays.contains(o.date)) ||
          (o.id == ObservanceId.masikShivaratri &&
              mahaShivaratriDays.contains(o.date)),
    );

    final list = results
        .where((o) => !o.date.isBefore(from) && !o.date.isAfter(to))
        .toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.id.index.compareTo(b.id.index);
      });

    return list;
  }

  DateTime? _observe(
    List<SolarDay> days,
    TithiSegment segment,
    ObservanceTime time,
  ) {
    for (final day in days) {
      final instant = _instant(day, time);
      if (instant != null && segment.contains(instant)) {
        return _dateOnly(day.date);
      }
    }

    if (time != ObservanceTime.sunrise) {
      final bySunrise = _observe(days, segment, ObservanceTime.sunrise);
      if (bySunrise != null) return bySunrise;
    }

    // Kshaya tithi: it never touches a sunrise. Use the day it begins on.
    for (final day in days) {
      final sunrise = day.sunrise;
      final nextSunrise = day.nextSunrise;
      if (sunrise == null || nextSunrise == null) continue;
      if (!segment.start.isBefore(sunrise) &&
          segment.start.isBefore(nextSunrise)) {
        return _dateOnly(day.date);
      }
    }

    return null;
  }

  DateTime? _instant(SolarDay day, ObservanceTime time) {
    final sunrise = day.sunrise;
    final sunset = day.sunset;
    if (sunrise == null || sunset == null) return null;

    switch (time) {
      case ObservanceTime.sunrise:
        return sunrise;
      case ObservanceTime.madhyahna:
        return _between(sunrise, sunset, 0.5);
      case ObservanceTime.aparahna:
        return _between(sunrise, sunset, 0.6);
      case ObservanceTime.pradosh:
        return sunset.add(_pradoshOffset);
      case ObservanceTime.nishita:
        final next = day.nextSunrise;
        return next == null ? null : _between(sunset, next, 0.5);
      case ObservanceTime.moonrise:
        return day.moonrise;
    }
  }

  DateTime _between(DateTime a, DateTime b, double fraction) {
    final span = b.difference(a).inMilliseconds;
    return a.add(Duration(milliseconds: (span * fraction).round()));
  }

  _MonthInfo? _monthAt(List<NewMoon> newMoons, DateTime instant) {
    for (var i = 0; i < newMoons.length - 1; i++) {
      final current = newMoons[i];
      final next = newMoons[i + 1];
      if (!instant.isBefore(current.time) && instant.isBefore(next.time)) {
        return _MonthInfo(
          LunarMonth.values[(current.sunSignIndex + 1) % 12],
          // No sankranti between two new moons → Adhik (leap) month.
          isAdhik: current.sunSignIndex == next.sunSignIndex,
        );
      }
    }
    return null;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

class _MonthInfo {
  final LunarMonth month;
  final bool isAdhik;

  const _MonthInfo(this.month, {required this.isAdhik});
}
