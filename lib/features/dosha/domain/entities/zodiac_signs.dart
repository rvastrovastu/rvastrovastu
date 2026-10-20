/// Sidereal sign names in zodiac order, matching the strings produced by
/// `SwissEphemerisAstrologyRepository` (`Kundali.ascendant`, `moonSign`,
/// `PlanetPosition.sign`).
const List<String> zodiacSigns = <String>[
  'Aries',
  'Taurus',
  'Gemini',
  'Cancer',
  'Leo',
  'Virgo',
  'Libra',
  'Scorpio',
  'Sagittarius',
  'Capricorn',
  'Aquarius',
  'Pisces',
];

/// Zero-based index of [sign] (Aries = 0), or `-1` when unknown.
int zodiacSignIndex(String sign) {
  final normalized = sign.trim().toLowerCase();
  for (var i = 0; i < zodiacSigns.length; i++) {
    if (zodiacSigns[i].toLowerCase() == normalized) return i;
  }
  return -1;
}

/// Whole-sign house (1–12) of [targetSignIndex] counted from
/// [referenceSignIndex], where the reference sign itself is house 1.
int houseFrom(int referenceSignIndex, int targetSignIndex) {
  return ((targetSignIndex - referenceSignIndex) % 12 + 12) % 12 + 1;
}
