class PlanetPosition {
  final String planet;
  final String sign;
  final int house;

  /// Full sidereal longitude, normalized to 0°–360°.
  final double longitude;

  /// Degree within the zodiac sign, 0°–30°.
  final double degree;

  final bool retrograde;
  final String? nakshatra;
  final int? nakshatraPada;

  const PlanetPosition({
    required this.planet,
    required this.sign,
    required this.house,
    required this.longitude,
    required this.degree,
    this.retrograde = false,
    this.nakshatra,
    this.nakshatraPada,
  });

  String get formattedDegree {
    return '${degree.toStringAsFixed(2)}°';
  }
}
