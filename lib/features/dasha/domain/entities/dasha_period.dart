enum DashaPlanet {
  sun,
  moon,
  mars,
  rahu,
  jupiter,
  saturn,
  mercury,
  ketu,
  venus,
}

extension DashaPlanetExtension on DashaPlanet {
  String get name {
    switch (this) {
      case DashaPlanet.sun:
        return 'Sun';
      case DashaPlanet.moon:
        return 'Moon';
      case DashaPlanet.mars:
        return 'Mars';
      case DashaPlanet.rahu:
        return 'Rahu';
      case DashaPlanet.jupiter:
        return 'Jupiter';
      case DashaPlanet.saturn:
        return 'Saturn';
      case DashaPlanet.mercury:
        return 'Mercury';
      case DashaPlanet.ketu:
        return 'Ketu';
      case DashaPlanet.venus:
        return 'Venus';
    }
  }
}

class DashaPeriod {
  final DashaPlanet planet;
  final DateTime startDate;
  final DateTime endDate;
  final int level;

  const DashaPeriod({
    required this.planet,
    required this.startDate,
    required this.endDate,
    this.level = 1,
  });

  Duration get duration => endDate.difference(startDate);

  bool contains(DateTime date) {
    return !date.isBefore(startDate) && date.isBefore(endDate);
  }

  DashaPeriod copyWith({
    DashaPlanet? planet,
    DateTime? startDate,
    DateTime? endDate,
    int? level,
  }) {
    return DashaPeriod(
      planet: planet ?? this.planet,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      level: level ?? this.level,
    );
  }
}
