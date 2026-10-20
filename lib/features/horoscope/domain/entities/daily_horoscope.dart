class DailyHoroscope {
  final DateTime date;

  /// Existing generated English content.
  ///
  /// Kept for backward compatibility and existing domain tests.
  final String career;
  final String finance;
  final String relationships;

  /// Stable semantic identifiers used by the presentation layer
  /// for localization.
  final String careerKey;
  final String financeKey;
  final String relationshipsKey;

  /// Dynamic values required by localized ICU messages.
  final String mahadasha;
  final String antardasha;
  final String nakshatra;

  const DailyHoroscope({
    required this.date,
    required this.career,
    required this.finance,
    required this.relationships,
    required this.careerKey,
    required this.financeKey,
    required this.relationshipsKey,
    required this.mahadasha,
    required this.antardasha,
    required this.nakshatra,
  });

  List<String> get insights => [career, finance, relationships];
}
