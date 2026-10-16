/// Raw astronomical inputs for building a Hindu festival calendar.
///
/// All instants are UTC. Calendar dates ([SolarDay.date],
/// [Sankranti.localDate]) are local dates at the chosen location, stored as
/// date-only `DateTime`s.
class LunarCalendarData {
  /// Consecutive tithi intervals covering the calculated range.
  final List<TithiSegment> tithis;

  /// Amavasya-to-Pratipada boundaries (new moons), oldest first.
  final List<NewMoon> newMoons;

  /// Sun's sidereal sign ingresses.
  final List<Sankranti> sankrantis;

  /// One entry per local calendar day.
  final List<SolarDay> days;

  const LunarCalendarData({
    required this.tithis,
    required this.newMoons,
    required this.sankrantis,
    required this.days,
  });
}

class TithiSegment {
  /// 0–29: Shukla Pratipada (0) … Purnima (14), Krishna Pratipada (15) …
  /// Amavasya (29).
  final int index;
  final DateTime start;
  final DateTime end;

  const TithiSegment({
    required this.index,
    required this.start,
    required this.end,
  });

  bool contains(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);
}

class NewMoon {
  final DateTime time;

  /// Sun's sidereal sign (Aries = 0) at the new moon. The amanta lunar month
  /// that begins here is named from this sign (Sun in Pisces → Chaitra).
  final int sunSignIndex;

  const NewMoon({required this.time, required this.sunSignIndex});
}

class Sankranti {
  final DateTime time;
  final DateTime localDate;

  /// The sign the Sun enters (Capricorn = 9 is Makar Sankranti).
  final int signIndex;

  const Sankranti({
    required this.time,
    required this.localDate,
    required this.signIndex,
  });
}

class SolarDay {
  final DateTime date;
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? nextSunrise;

  /// Moonrise on this local date, or `null` if the Moon does not rise today.
  final DateTime? moonrise;

  const SolarDay({
    required this.date,
    this.sunrise,
    this.sunset,
    this.nextSunrise,
    this.moonrise,
  });
}
