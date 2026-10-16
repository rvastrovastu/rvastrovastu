/// Overall Manglik (Mangal / Kuja) dosha verdict.
enum ManglikStatus {
  /// Mars is not in a Manglik house from Lagna, Moon or Venus.
  none,

  /// Mars is in a Manglik house from the Moon or Venus only — commonly
  /// described as a mild (anshik) Manglik placement.
  mild,

  /// Mars is in a Manglik house from the Lagna (ascendant).
  present,

  /// A Manglik placement exists, but a commonly cited cancellation applies.
  cancelled,
}

/// Commonly cited traditional cancellations (parihara) of Manglik dosha.
///
/// Traditions differ on which of these apply; the app reports them as
/// information, not as a final ruling.
enum ManglikCancellation {
  /// Mars in its own sign (Aries, Scorpio) or exalted (Capricorn).
  marsInOwnOrExaltedSign,

  /// Jupiter in the same sign as Mars.
  jupiterConjunctMars,

  /// Jupiter aspects Mars (5th, 7th or 9th sign from Jupiter).
  jupiterAspectsMars,

  /// Moon in the same sign as Mars (Chandra–Mangal yoga).
  moonConjunctMars,
}

class ManglikResult {
  final ManglikStatus status;

  /// Whole-sign house of Mars counted from the ascendant.
  final int marsHouseFromLagna;

  /// Whole-sign house of Mars counted from the Moon.
  final int marsHouseFromMoon;

  /// Whole-sign house of Mars counted from Venus.
  final int marsHouseFromVenus;

  final bool fromLagna;
  final bool fromMoon;
  final bool fromVenus;

  final String marsSign;
  final List<ManglikCancellation> cancellations;

  const ManglikResult({
    required this.status,
    required this.marsHouseFromLagna,
    required this.marsHouseFromMoon,
    required this.marsHouseFromVenus,
    required this.fromLagna,
    required this.fromMoon,
    required this.fromVenus,
    required this.marsSign,
    this.cancellations = const [],
  });

  /// Whether Mars occupies a Manglik house from any reference point,
  /// before cancellations are considered.
  bool get hasManglikPlacement => fromLagna || fromMoon || fromVenus;

  /// Whether the dosha is treated as active for matching purposes.
  bool get isEffectivelyManglik =>
      status == ManglikStatus.present || status == ManglikStatus.mild;
}

/// How two partners' Manglik status compares in traditional matching.
enum ManglikMatch {
  /// Neither partner has an active Manglik dosha.
  neitherManglik,

  /// Both partners are Manglik; traditionally considered to balance out.
  bothManglik,

  /// Only one partner is Manglik; traditionally reviewed further.
  onlyOneManglik,
}

ManglikMatch compareManglik(ManglikResult first, ManglikResult second) {
  final a = first.isEffectivelyManglik;
  final b = second.isEffectivelyManglik;
  if (a && b) return ManglikMatch.bothManglik;
  if (!a && !b) return ManglikMatch.neitherManglik;
  return ManglikMatch.onlyOneManglik;
}
