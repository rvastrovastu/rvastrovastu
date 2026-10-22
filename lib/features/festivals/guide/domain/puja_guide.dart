import '../../domain/entities/calendar_observance.dart';

/// The written guide for one observance, in one language.
class PujaGuide {
  final ObservanceId id;
  final String deity;

  /// What the observance is and why it is kept.
  final String about;

  /// The vrat katha or the story behind the festival.
  final String story;
  final String fasting;
  final List<String> benefits;
  final List<String> dos;
  final List<String> donts;
  final List<String> samagri;
  final List<String> steps;

  /// Meanings of the spec's mantras, in the same order.
  final List<String> mantraMeanings;

  const PujaGuide({
    required this.id,
    required this.deity,
    required this.about,
    required this.story,
    required this.fasting,
    required this.benefits,
    required this.dos,
    required this.donts,
    required this.samagri,
    required this.steps,
    required this.mantraMeanings,
  });

  factory PujaGuide.fromJson(ObservanceId id, Map<String, dynamic> json) {
    List<String> list(String key) =>
        [for (final item in json[key] as List) item as String];
    return PujaGuide(
      id: id,
      deity: json['deity'] as String,
      about: json['about'] as String,
      story: json['story'] as String,
      fasting: json['fasting'] as String,
      benefits: list('benefits'),
      dos: list('dos'),
      donts: list('donts'),
      samagri: list('samagri'),
      steps: list('steps'),
      mantraMeanings: list('mantraMeanings'),
    );
  }
}

/// An aarti, line by line in Devanagari and in English letters. Blank
/// lines separate verses; both lists have the same length.
class Aarti {
  final String key;
  final String titleDevanagari;
  final String titleLatin;
  final List<String> devanagari;
  final List<String> latin;

  const Aarti({
    required this.key,
    required this.titleDevanagari,
    required this.titleLatin,
    required this.devanagari,
    required this.latin,
  });

  factory Aarti.fromJson(String key, Map<String, dynamic> json) => Aarti(
    key: key,
    titleDevanagari: json['titleDevanagari'] as String,
    titleLatin: json['titleLatin'] as String,
    devanagari: [for (final l in json['devanagari'] as List) l as String],
    latin: [for (final l in json['latin'] as List) l as String],
  );
}
