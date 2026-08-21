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

  /// Generates Mahadashas from the Moon's birth Nakshatra.
  DashaTimeline call({required DashaBirthData birthData}) {
    final start = CalculateVimshottariStart()(birthData: birthData);

    final periods = <DashaPeriod>[];

    var currentDate = birthData.birthDate;

    final startIndex = sequence.indexOf(start.planet);

    if (startIndex < 0) {
      return const DashaTimeline(periods: []);
    }

    for (var i = 0; i < sequence.length; i++) {
      final planet = sequence[(startIndex + i) % sequence.length];

      final fullYears = durations[planet]!;

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
  List<DashaPeriod> antardashas(DashaPeriod mahadasha) {
    final periods = <DashaPeriod>[];

    final startIndex = sequence.indexOf(mahadasha.planet);

    if (startIndex < 0) {
      return periods;
    }

    var currentDate = mahadasha.startDate;

    final mahadashaMilliseconds = mahadasha.endDate
        .difference(mahadasha.startDate)
        .inMilliseconds;

    for (var i = 0; i < sequence.length; i++) {
      final planet = sequence[(startIndex + i) % sequence.length];

      final planetYears = durations[planet]!;

      final fraction = planetYears / totalYears;

      final durationMilliseconds = (mahadashaMilliseconds * fraction).round();

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

  /// Calculates Pratyantardashas inside an Antardasha.
  List<DashaPeriod> pratyantardashas(DashaPeriod antardasha) {
    final periods = <DashaPeriod>[];

    final startIndex = sequence.indexOf(antardasha.planet);

    if (startIndex < 0) {
      return periods;
    }

    var currentDate = antardasha.startDate;

    final antardashaMilliseconds = antardasha.endDate
        .difference(antardasha.startDate)
        .inMilliseconds;

    for (var i = 0; i < sequence.length; i++) {
      final planet = sequence[(startIndex + i) % sequence.length];

      final planetYears = durations[planet]!;

      final fraction = planetYears / totalYears;

      final durationMilliseconds = (antardashaMilliseconds * fraction).round();

      final endDate = i == sequence.length - 1
          ? antardasha.endDate
          : currentDate.add(Duration(milliseconds: durationMilliseconds));

      periods.add(
        DashaPeriod(
          planet: planet,
          startDate: currentDate,
          endDate: endDate,
          level: 3,
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
