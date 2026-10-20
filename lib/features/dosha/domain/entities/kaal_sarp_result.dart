/// The twelve named Kaal Sarp yogas, keyed by Rahu's house from the Lagna.
enum KaalSarpType {
  anant, // Rahu in house 1
  kulik, // 2
  vasuki, // 3
  shankhpal, // 4
  padma, // 5
  mahapadma, // 6
  takshak, // 7
  karkotak, // 8
  shankhachud, // 9
  ghatak, // 10
  vishdhar, // 11
  sheshnag, // 12
}

KaalSarpType kaalSarpTypeForRahuHouse(int house) {
  assert(house >= 1 && house <= 12);
  return KaalSarpType.values[(house - 1) % 12];
}

enum KaalSarpStatus {
  /// At least one planet lies outside the Rahu–Ketu axis on each side.
  none,

  /// All seven planets are hemmed between Rahu and Ketu.
  full,

  /// Exactly one planet lies outside the Rahu–Ketu hemisphere; some
  /// traditions call this a partial (anshik) Kaal Sarp.
  partial,
}

/// Which half of the Rahu–Ketu axis holds the planets.
enum KaalSarpDirection {
  /// Planets fall in the zodiacal arc from Rahu to Ketu.
  rahuToKetu,

  /// Planets fall in the arc from Ketu to Rahu — called Kaal Amrit
  /// yoga in some traditions.
  ketuToRahu,
}

class KaalSarpResult {
  final KaalSarpStatus status;
  final KaalSarpDirection? direction;
  final KaalSarpType? type;
  final int rahuHouse;
  final int ketuHouse;

  /// Planets lying outside the hemmed arc (empty for a full Kaal Sarp).
  final List<String> planetsOutside;

  const KaalSarpResult({
    required this.status,
    required this.rahuHouse,
    required this.ketuHouse,
    this.direction,
    this.type,
    this.planetsOutside = const [],
  });

  bool get isPresent => status != KaalSarpStatus.none;
}
