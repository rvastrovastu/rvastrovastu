class PlanetPosition {
  final String planet;
  final String sign;
  final int house;
  final double degree;
  final bool retrograde;
  final String? nakshatra;
  final int? nakshatraPada;

  const PlanetPosition({
    required this.planet,
    required this.sign,
    required this.house,
    required this.degree,
    this.retrograde = false,
    this.nakshatra,
    this.nakshatraPada,
  });

  String get formattedDegree {
    return '${degree.toStringAsFixed(2)}°';
  }
}
