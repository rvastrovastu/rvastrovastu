class RashiHouse {
  final int house;
  final String sign;
  final List<String> planets;

  const RashiHouse({
    required this.house,
    required this.sign,
    required this.planets,
  });

  bool get hasPlanets => planets.isNotEmpty;

  String get planetSummary => planets.isEmpty ? '—' : planets.join(', ');
}

class RashiChart {
  final List<RashiHouse> houses;

  const RashiChart({required this.houses});

  RashiHouse? house(int number) {
    for (final item in houses) {
      if (item.house == number) {
        return item;
      }
    }
    return null;
  }

  List<RashiHouse> get occupiedHouses =>
      houses.where((item) => item.hasPlanets).toList();

  bool get hasAnyPlanets => houses.any((item) => item.hasPlanets);
}
