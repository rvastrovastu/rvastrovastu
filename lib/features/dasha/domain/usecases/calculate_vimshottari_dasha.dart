import '../entities/dasha_period.dart';
import '../entities/dasha_timeline.dart';

class CalculateVimshottariDasha {
  /// Vimshottari Mahadasha durations in years.
  static const Map<DashaPlanet, double> durations = {
    DashaPlanet.ketu: 7,
    DashaPlanet.venus: 20,
    DashaPlanet.sun: 6,
    DashaPlanet.moon: 10,
    DashaPlanet.mars: 7,
    DashaPlanet.rahu: 18,
    DashaPlanet.jupiter: 16,
    DashaPlanet.saturn: 19,
    DashaPlanet.mercury: 17,
  };

  /// Standard Vimshottari sequence.
  static const List<DashaPlanet> sequence = [
    DashaPlanet.ketu,
    DashaPlanet.venus,
    DashaPlanet.sun,
    DashaPlanet.moon,
    DashaPlanet.mars,
    DashaPlanet.rahu,
    DashaPlanet.jupiter,
    DashaPlanet.saturn,
    DashaPlanet.mercury,
  ];

  /// Total Vimshottari cycle = 120 years.
  static const double totalYears = 120;

  /// Generates Mahadashas starting from a supplied planet.
  ///
  /// `firstBalance` represents the fraction of the first Mahadasha
  /// remaining at birth. A value of 1.0 means the complete Mahadasha
  /// remains; 0.5 means half remains.
  DashaTimeline call({
    required DateTime birthDate,
    DashaPlanet startingPlanet = DashaPlanet.ketu,
    double firstBalance = 1.0,
  }) {
    final periods = <DashaPeriod>[];

    var currentDate = birthDate;

    final startIndex = sequence.indexOf(startingPlanet);

    if (startIndex < 0) {
      return const DashaTimeline(periods: []);
    }

    final balance = firstBalance.clamp(0.0, 1.0);

    for (var i = 0; i < sequence.length; i++) {
      final planet = sequence[(startIndex + i) % sequence.length];

      final fullYears = durations[planet]!;

      final years = i == 0 ? fullYears * balance : fullYears;

      final endDate = _addYearsFraction(currentDate, years);

      periods.add(
        DashaPeriod(
          planet: planet,
          startDate: currentDate,
          endDate: endDate,
          level: 1,
        ),
      );

      currentDate = endDate;
    }

    return DashaTimeline(periods: periods);
  }

  /// Calculates Antardashas inside a Mahadasha.
  List<DashaPeriod> antardashas(DashaPeriod mahadasha) {
    final periods = <DashaPeriod>[];

    final startIndex = sequence.indexOf(mahadasha.planet);

    if (startIndex < 0) {
      return periods;
    }

    var currentDate = mahadasha.startDate;

    final mahadashaDays = mahadasha.endDate
        .difference(mahadasha.startDate)
        .inMilliseconds;

    for (var i = 0; i < sequence.length; i++) {
      final planet = sequence[(startIndex + i) % sequence.length];

      final planetYears = durations[planet]!;

      final fraction = planetYears / totalYears;

      final durationMilliseconds = (mahadashaDays * fraction).round();

      final endDate = i == sequence.length - 1
          ? mahadasha.endDate
          : currentDate.add(Duration(milliseconds: durationMilliseconds));

      periods.add(
        DashaPeriod(
          planet: planet,
          startDate: currentDate,
          endDate: endDate,
          level: 2,
        ),
      );

      currentDate = endDate;
    }

    return periods;
  }

  DateTime _addYearsFraction(DateTime date, double years) {
    final wholeYears = years.floor();
    final remainingYears = years - wholeYears;

    var result = DateTime(
      date.year + wholeYears,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );

    final daysInYear = DateTime(
      result.year + 1,
      result.month,
      result.day,
    ).difference(DateTime(result.year, result.month, result.day)).inDays;

    final additionalDays = (remainingYears * daysInYear).round();

    result = result.add(Duration(days: additionalDays));

    return result;
  }
}
