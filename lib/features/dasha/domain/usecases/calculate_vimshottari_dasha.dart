import '../entities/dasha_period.dart';
import '../entities/dasha_timeline.dart';

class CalculateVimshottariDasha {
  static const Map<DashaPlanet, double> durations = {
    DashaPlanet.sun: 6,
    DashaPlanet.moon: 10,
    DashaPlanet.mars: 7,
    DashaPlanet.rahu: 18,
    DashaPlanet.jupiter: 16,
    DashaPlanet.saturn: 19,
    DashaPlanet.mercury: 17,
    DashaPlanet.ketu: 7,
    DashaPlanet.venus: 20,
  };

  static const List<DashaPlanet> sequence = [
    DashaPlanet.sun,
    DashaPlanet.moon,
    DashaPlanet.mars,
    DashaPlanet.rahu,
    DashaPlanet.jupiter,
    DashaPlanet.saturn,
    DashaPlanet.mercury,
    DashaPlanet.ketu,
    DashaPlanet.venus,
  ];

  DashaTimeline call({
    required DateTime birthDate,
    DashaPlanet startingPlanet = DashaPlanet.sun,
  }) {
    final periods = <DashaPeriod>[];

    var currentDate = birthDate;

    final startIndex = sequence.indexOf(startingPlanet);

    for (var i = 0; i < sequence.length; i++) {
      final planet = sequence[(startIndex + i) % sequence.length];
      final years = durations[planet]!;

      final endDate = DateTime(
        currentDate.year + years.toInt(),
        currentDate.month,
        currentDate.day,
        currentDate.hour,
        currentDate.minute,
        currentDate.second,
      );

      periods.add(
        DashaPeriod(
          planet: planet,
          startDate: currentDate,
          endDate: endDate,
        ),
      );

      currentDate = endDate;
    }

    return DashaTimeline(periods: periods);
  }
}
