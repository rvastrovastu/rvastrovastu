import '../astrology/domain/entities/kundali.dart';
import '../dosha/domain/entities/zodiac_signs.dart';

/// Houses (counted from each contributor) where it gives a bindu to each
/// planet's Bhinnashtakavarga, per Brihat Parashara Hora Shastra.
/// Contributors in order: Sun, Moon, Mars, Mercury, Jupiter, Venus,
/// Saturn, Lagna.
const Map<String, List<List<int>>> _bindus = {
  'Sun': [
    [1, 2, 4, 7, 8, 9, 10, 11],
    [3, 6, 10, 11],
    [1, 2, 4, 7, 8, 9, 10, 11],
    [3, 5, 6, 9, 10, 11, 12],
    [5, 6, 9, 11],
    [6, 7, 12],
    [1, 2, 4, 7, 8, 9, 10, 11],
    [3, 4, 6, 10, 11, 12],
  ],
  'Moon': [
    [3, 6, 7, 8, 10, 11],
    [1, 3, 6, 7, 10, 11],
    [2, 3, 5, 6, 9, 10, 11],
    [1, 3, 4, 5, 7, 8, 10, 11],
    [1, 4, 7, 8, 10, 11, 12],
    [3, 4, 5, 7, 9, 10, 11],
    [3, 5, 6, 11],
    [3, 6, 10, 11],
  ],
  'Mars': [
    [3, 5, 6, 10, 11],
    [3, 6, 11],
    [1, 2, 4, 7, 8, 10, 11],
    [3, 5, 6, 11],
    [6, 10, 11, 12],
    [6, 8, 11, 12],
    [1, 4, 7, 8, 9, 10, 11],
    [1, 3, 6, 10, 11],
  ],
  'Mercury': [
    [5, 6, 9, 11, 12],
    [2, 4, 6, 8, 10, 11],
    [1, 2, 4, 7, 8, 9, 10, 11],
    [1, 3, 5, 6, 9, 10, 11, 12],
    [6, 8, 11, 12],
    [1, 2, 3, 4, 5, 8, 9, 11],
    [1, 2, 4, 7, 8, 9, 10, 11],
    [1, 2, 4, 6, 8, 10, 11],
  ],
  'Jupiter': [
    [1, 2, 3, 4, 7, 8, 9, 10, 11],
    [2, 5, 7, 9, 11],
    [1, 2, 4, 7, 8, 10, 11],
    [1, 2, 4, 5, 6, 9, 10, 11],
    [1, 2, 3, 4, 7, 8, 10, 11],
    [2, 5, 6, 9, 10, 11],
    [3, 5, 6, 12],
    [1, 2, 4, 5, 6, 7, 9, 10, 11],
  ],
  'Venus': [
    [8, 11, 12],
    [1, 2, 3, 4, 5, 8, 9, 11, 12],
    [3, 5, 6, 9, 11, 12],
    [3, 5, 6, 9, 11],
    [5, 8, 9, 10, 11],
    [1, 2, 3, 4, 5, 8, 9, 10, 11],
    [3, 4, 5, 8, 9, 10, 11],
    [1, 2, 3, 4, 5, 8, 9, 11],
  ],
  'Saturn': [
    [1, 2, 4, 7, 8, 10, 11],
    [3, 6, 11],
    [3, 5, 6, 10, 11, 12],
    [6, 8, 9, 10, 11, 12],
    [5, 6, 11, 12],
    [6, 11, 12],
    [3, 5, 6, 11],
    [1, 3, 4, 6, 10, 11],
  ],
};

const ashtakavargaPlanets = [
  'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', //
];

class Ashtakavarga {
  /// Bindus per sign (Aries = 0) for each planet.
  final Map<String, List<int>> bhinna;

  /// Sum of the seven, per sign. Always totals 337.
  final List<int> sarva;

  /// The Lagna sign, to read the signs as houses.
  final int lagnaSign;

  const Ashtakavarga({
    required this.bhinna,
    required this.sarva,
    required this.lagnaSign,
  });

  /// Sarvashtakavarga points of house [house] (1–12) from the Lagna.
  int houseSarva(int house) => sarva[(lagnaSign + house - 1) % 12];
}

/// Ashtakavarga from the birth chart's signs (Rahu and Ketu take no part).
Ashtakavarga calculateAshtakavarga(Kundali kundali) {
  final lagna = zodiacSignIndex(kundali.ascendant);
  if (lagna < 0) throw ArgumentError('Unknown Lagna: ${kundali.ascendant}');

  final positions = <int>[
    for (final p in ashtakavargaPlanets)
      zodiacSignIndex(kundali.planets.firstWhere((x) => x.planet == p).sign),
    lagna,
  ];

  final bhinna = <String, List<int>>{};
  for (final planet in ashtakavargaPlanets) {
    final signs = List<int>.filled(12, 0);
    final table = _bindus[planet]!;
    for (var c = 0; c < 8; c++) {
      for (final house in table[c]) {
        signs[(positions[c] + house - 1) % 12]++;
      }
    }
    bhinna[planet] = signs;
  }

  final sarva = [
    for (var s = 0; s < 12; s++)
      bhinna.values.fold<int>(0, (sum, list) => sum + list[s]),
  ];
  return Ashtakavarga(bhinna: bhinna, sarva: sarva, lagnaSign: lagna);
}
