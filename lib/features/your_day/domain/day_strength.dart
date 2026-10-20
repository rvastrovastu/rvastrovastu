/// Personal daily strength from the transiting Moon: Tara Bala (counted
/// from the birth nakshatra) and Chandra Bala (counted from the natal Moon
/// sign), as used in classical muhurta.
library;

/// Nakshatra names in order, matching `Kundali.nakshatra` and the
/// `nakshatraName` localization keys (spaces become underscores).
const List<String> nakshatraNames = <String>[
  'Ashwini',
  'Bharani',
  'Krittika',
  'Rohini',
  'Mrigashira',
  'Ardra',
  'Punarvasu',
  'Pushya',
  'Ashlesha',
  'Magha',
  'Purva Phalguni',
  'Uttara Phalguni',
  'Hasta',
  'Chitra',
  'Swati',
  'Vishakha',
  'Anuradha',
  'Jyeshtha',
  'Mula',
  'Purva Ashadha',
  'Uttara Ashadha',
  'Shravana',
  'Dhanishtha',
  'Shatabhisha',
  'Purva Bhadrapada',
  'Uttara Bhadrapada',
  'Revati',
];

const double degreesPerNakshatra = 360 / 27;

int nakshatraIndexOf(double siderealLongitude) =>
    (_normalize(siderealLongitude) / degreesPerNakshatra).floor() % 27;

int signIndexOf(double siderealLongitude) =>
    (_normalize(siderealLongitude) / 30).floor() % 12;

double _normalize(double longitude) {
  final value = longitude % 360;
  return value < 0 ? value + 360 : value;
}

enum Strength { good, weak, bad }

/// The nine Taras, counted from the birth nakshatra in cycles of nine.
enum Tara {
  janma(Strength.weak),
  sampat(Strength.good),
  vipat(Strength.bad),
  kshema(Strength.good),
  pratyari(Strength.bad),
  sadhaka(Strength.good),
  vadha(Strength.bad),
  mitra(Strength.good),
  paramaMitra(Strength.good);

  final Strength strength;

  const Tara(this.strength);

  /// The Tara of [transitNakshatra] for someone born in [birthNakshatra]
  /// (both 0–26).
  static Tara of(int birthNakshatra, int transitNakshatra) {
    final count = (transitNakshatra - birthNakshatra) % 27;
    return Tara.values[(count < 0 ? count + 27 : count) % 9];
  }
}

enum DayVerdict { good, mixed, caution }

class DayStrength {
  final int birthNakshatra;
  final int natalMoonSign;
  final int transitNakshatra;
  final int transitMoonSign;

  const DayStrength({
    required this.birthNakshatra,
    required this.natalMoonSign,
    required this.transitNakshatra,
    required this.transitMoonSign,
  });

  factory DayStrength.fromLongitudes({
    required double natalMoon,
    required double transitMoon,
  }) => DayStrength(
    birthNakshatra: nakshatraIndexOf(natalMoon),
    natalMoonSign: signIndexOf(natalMoon),
    transitNakshatra: nakshatraIndexOf(transitMoon),
    transitMoonSign: signIndexOf(transitMoon),
  );

  Tara get tara => Tara.of(birthNakshatra, transitNakshatra);

  /// House (1–12) of the transiting Moon counted from the natal Moon sign.
  int get chandraHouse => (transitMoonSign - natalMoonSign + 12) % 12 + 1;

  /// Good from the 1st, 3rd, 6th, 7th, 10th and 11th; the 8th
  /// (Chandrashtama) is the one to avoid; the rest are weak.
  Strength get chandraBala {
    const good = {1, 3, 6, 7, 10, 11};
    if (good.contains(chandraHouse)) return Strength.good;
    if (chandraHouse == 8) return Strength.bad;
    return Strength.weak;
  }

  bool get isChandrashtama => chandraHouse == 8;

  DayVerdict get verdict {
    if (tara.strength == Strength.bad || chandraBala == Strength.bad) {
      return DayVerdict.caution;
    }
    if (tara.strength == Strength.good && chandraBala == Strength.good) {
      return DayVerdict.good;
    }
    return DayVerdict.mixed;
  }
}

/// The transiting Moon now, and when it next changes nakshatra and sign.
class MoonNow {
  final double longitude;
  final DateTime nakshatraEndsUtc;
  final DateTime signEndsUtc;

  MoonNow({
    required this.longitude,
    required DateTime nakshatraEndsUtc,
    required DateTime signEndsUtc,
  }) : nakshatraEndsUtc = nakshatraEndsUtc.toUtc(),
       signEndsUtc = signEndsUtc.toUtc();
}
