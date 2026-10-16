import 'koota_score.dart';

/// Result of a traditional eight-factor Guna Milan calculation.
class CompatibilityResult {
  final List<KootaScore> kootas;
  final List<String> traditionalFlags;

  const CompatibilityResult({
    required this.kootas,
    this.traditionalFlags = const [],
  });

  double get totalScore =>
      kootas.fold<double>(0, (total, item) => total + item.score);

  double get maximumScore =>
      kootas.fold<double>(0, (total, item) => total + item.maximum);

  bool get hasEightKootas => kootas.length == 8;

  /// A conventional threshold, not a prediction of relationship success.
  bool get meetsTraditionalMinimum => totalScore >= 18;
}
