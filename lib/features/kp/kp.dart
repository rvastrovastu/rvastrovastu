import '../yogas/domain/usecases/detect_yogas.dart';

/// Vimshottari order and years, which KP uses to split every nakshatra
/// into nine unequal subs.
const kpDashaOrder = [
  'Ketu', 'Venus', 'Sun', 'Moon', 'Mars', 'Rahu', 'Jupiter', 'Saturn', //
  'Mercury',
];
const kpDashaYears = {
  'Ketu': 7,
  'Venus': 20,
  'Sun': 6,
  'Moon': 10,
  'Mars': 7,
  'Rahu': 18,
  'Jupiter': 16,
  'Saturn': 19,
  'Mercury': 17,
};

const double _star = 360 / 27;

double _norm(double v) => (v % 360 + 360) % 360;

/// Sign, star and sub lords of a sidereal longitude.
class KpLords {
  final String sign;
  final String star;
  final String sub;

  const KpLords(this.sign, this.star, this.sub);

  @override
  bool operator ==(Object other) =>
      other is KpLords &&
      other.sign == sign &&
      other.star == star &&
      other.sub == sub;

  @override
  int get hashCode => Object.hash(sign, star, sub);

  @override
  String toString() => 'KpLords($sign, $star, $sub)';
}

KpLords kpLords(double longitude) {
  final lon = _norm(longitude);
  final nak = (lon / _star).floor() % 27;
  final start = nak % 9;
  final within = lon - nak * _star;
  var acc = 0.0;
  var sub = kpDashaOrder[(start + 8) % 9];
  for (var i = 0; i < 9; i++) {
    final lord = kpDashaOrder[(start + i) % 9];
    acc += kpDashaYears[lord]! / 120 * _star;
    if (within < acc - 1e-9) {
      sub = lord;
      break;
    }
  }
  return KpLords(
    DetectYogas.signLords[(lon / 30).floor() % 12],
    kpDashaOrder[start],
    sub,
  );
}

/// Weekday lord, Sunday = Sun.
String dayLord(DateTime localDate) => const [
  'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', 'Sun', //
][localDate.weekday - 1];

/// A KP chart: Placidus cusps and planets, both sidereal (KP ayanamsa).
class KpChart {
  /// Cusps 1–12 at indices 0–11.
  final List<double> cusps;

  /// Sidereal longitude of each of the nine planets.
  final Map<String, double> planets;

  /// Local clock time of the chart, for the day lord.
  final DateTime local;

  const KpChart({
    required this.cusps,
    required this.planets,
    required this.local,
  });

  double get ascendant => cusps[0];

  /// Placidus house (1–12) holding [longitude].
  int houseOf(double longitude) {
    final lon = _norm(longitude);
    for (var i = 0; i < 12; i++) {
      final from = cusps[i];
      final span = _norm(cusps[(i + 1) % 12] - from);
      if (_norm(lon - from) < span) return i + 1;
    }
    return 1;
  }

  /// Houses whose cusp falls in a sign ruled by [planet].
  List<int> housesOwnedBy(String planet) => [
    for (var i = 0; i < 12; i++)
      if (kpLords(cusps[i]).sign == planet) i + 1,
  ];

  /// Houses [planet] signifies, strongest level first: houses occupied by
  /// its star lord, the house it occupies, houses owned by its star lord,
  /// houses it owns.
  List<int> significations(String planet) {
    final star = kpLords(planets[planet]!).star;
    final ordered = <int>[
      houseOf(planets[star]!),
      houseOf(planets[planet]!),
      ...housesOwnedBy(star),
      ...housesOwnedBy(planet),
    ];
    final seen = <int>{};
    return [
      for (final h in ordered)
        if (seen.add(h)) h,
    ];
  }

  /// KP ruling planets at the moment of the chart.
  List<(String role, String planet)> get rulingPlanets {
    final asc = kpLords(ascendant);
    final moon = kpLords(planets['Moon']!);
    return [
      ('ascStar', asc.star),
      ('ascSign', asc.sign),
      ('moonStar', moon.star),
      ('moonSign', moon.sign),
      ('day', dayLord(local)),
    ];
  }

  /// Whether the sub lord of the question's main cusp signifies any of its
  /// favourable houses (the core KP horary test).
  KpVerdict judge(KpQuestion q) {
    final subLord = kpLords(cusps[q.cusp - 1]).sub;
    final signified = significations(subLord);
    final hits = [
      for (final h in q.favourable)
        if (signified.contains(h)) h,
    ];
    return KpVerdict(subLord, signified, hits);
  }
}

/// Common horary questions: the cusp to read and the houses that support
/// a yes.
enum KpQuestion {
  marriage(7, [2, 7, 11]),
  career(10, [2, 6, 10, 11]),
  money(11, [2, 6, 11]),
  property(4, [4, 11, 12]),
  education(4, [4, 9, 11]),
  children(5, [2, 5, 11]),
  travel(12, [3, 9, 12]),
  health(1, [1, 5, 11]),
  dispute(6, [6, 11]);

  final int cusp;
  final List<int> favourable;

  const KpQuestion(this.cusp, this.favourable);
}

class KpVerdict {
  final String subLord;
  final List<int> signified;
  final List<int> supporting;

  const KpVerdict(this.subLord, this.signified, this.supporting);

  bool get promising => supporting.isNotEmpty;
}
