/// Score for one traditional Ashtakoota matching factor.
class KootaScore {
  final String name;
  final double score;
  final double maximum;
  final String explanation;

  const KootaScore({
    required this.name,
    required this.score,
    required this.maximum,
    required this.explanation,
  }) : assert(score >= 0),
       assert(maximum > 0),
       assert(score <= maximum);

  /// Percentage safely bounded to the range 0–100.
  ///
  /// The zero-maximum guard protects release builds if invalid data
  /// bypasses constructor assertions.
  double get percentage {
    if (maximum <= 0) return 0;
    return (score / maximum * 100).clamp(0.0, 100.0).toDouble();
  }
}
