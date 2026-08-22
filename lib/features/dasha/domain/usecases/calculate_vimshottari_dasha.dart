import '../entities/dasha_birth_data.dart';
import '../entities/dasha_period.dart';
import '../entities/dasha_timeline.dart';
import 'calculate_vimshottari_start.dart';

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

  /// Total Vimshottari cycle.
  static const double totalYears = 120;

  /// Generates Vimshottari Mahadashas beginning from the Moon's
  /// birth Nakshatra and continuing for multiple cycles.
  ///
  /// The first Mahadasha is shortened according to the remaining
  /// balance at birth.
  DashaTimeline call({required DashaBirthData birthData}) {
    final start = CalculateVimshottariStart()(birthData: birthData);

    final periods = <DashaPeriod>[];

    final startIndex = sequence.indexOf(start.planet);

    if (startIndex < 0) {
      return const DashaTimeline(periods: []);
    }

    var currentDate = birthData.birthDate;

    for (var i = 0; i < sequence.length; i++) {
      final planet = sequence[(startIndex + i) % sequence.length];

      final fullYears = durations[planet]!;

      // The first Mahadasha contains only the remaining balance
      // at the time of birth.
      final years = i == 0 ? fullYears * start.balance : fullYears;

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
  ///
  /// The Antardasha sequence starts with the Mahadasha lord and
  /// follows the standard Vimshottari planetary sequence.
  List<DashaPeriod> antardashas(DashaPeriod mahadasha) {
    return _subPeriods(parent: mahadasha, level: 2);
  }

  /// Calculates Pratyantardashas inside an Antardasha.
  ///
  /// The Pratyantardasha sequence starts with the Antardasha lord.
  List<DashaPeriod> pratyantardashas(DashaPeriod antardasha) {
    return _subPeriods(parent: antardasha, level: 3);
  }

  /// Generic Vimshottari subdivision calculator.
  ///
  /// Each child period receives a proportional duration based on
  /// the planet's Vimshottari weight:
  ///
  ///     child duration = parent duration × planet years / 120
  List<DashaPeriod> _subPeriods({
    required DashaPeriod parent,
    required int level,
  }) {
    final periods = <DashaPeriod>[];

    final startIndex = sequence.indexOf(parent.planet);

    if (startIndex < 0) {
      return periods;
    }

    var currentDate = parent.startDate;

    final parentMilliseconds = parent.endDate
        .difference(parent.startDate)
        .inMilliseconds;

    for (var i = 0; i < sequence.length; i++) {
      final planet = sequence[(startIndex + i) % sequence.length];

      final planetYears = durations[planet]!;

      final fraction = planetYears / totalYears;

      final durationMilliseconds = (parentMilliseconds * fraction).round();

      final endDate = i == sequence.length - 1
          ? parent.endDate
          : currentDate.add(Duration(milliseconds: durationMilliseconds));

      periods.add(
        DashaPeriod(
          planet: planet,
          startDate: currentDate,
          endDate: endDate,
          level: level,
        ),
      );

      currentDate = endDate;
    }

    return periods;
  }

  /// Adds a fractional number of years to a DateTime.
  ///
  /// Whole years are added first. The remaining fraction is converted
  /// using a 365.2425-day tropical-year approximation.
  DateTime _addYearsFraction(DateTime date, double years) {
    if (years <= 0) {
      return date;
    }

    final wholeYears = years.floor();
    final remainingYears = years - wholeYears;

    var result = _addWholeYears(date, wholeYears);

    if (remainingYears <= 0) {
      return result;
    }

    const averageDaysPerYear = 365.2425;

    final additionalDays = (remainingYears * averageDaysPerYear).round();

    result = result.add(Duration(days: additionalDays));

    return result;
  }

  DateTime _addWholeYears(DateTime date, int years) {
    final targetYear = date.year + years;

    // Handle February 29 when the target year is not a leap year.
    final lastDayOfTargetMonth = DateTime(targetYear, date.month + 1, 0).day;

    final targetDay = date.day > lastDayOfTargetMonth
        ? lastDayOfTargetMonth
        : date.day;

    return DateTime(
      targetYear,
      date.month,
      targetDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }
}
