import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/domain/entities/planet_position.dart';
import '../../../dosha/domain/entities/zodiac_signs.dart';
import '../entities/yoga.dart';

/// Detects widely used Parashari yogas with whole-sign houses.
///
/// Only conjunction-based forms are checked for Raj, Dhana and similar
/// lordship yogas; aspect and exchange (parivartana) variants are not, so
/// the list errs on the side of fewer, clearer results.
class DetectYogas {
  const DetectYogas();

  static const List<String> _order = [
    'Sun',
    'Moon',
    'Mars',
    'Mercury',
    'Jupiter',
    'Venus',
    'Saturn',
    'Rahu',
    'Ketu',
  ];

  /// Sign lord for each sign index, Aries = 0.
  static const List<String> signLords = [
    'Mars',
    'Venus',
    'Mercury',
    'Moon',
    'Sun',
    'Mercury',
    'Venus',
    'Mars',
    'Jupiter',
    'Saturn',
    'Saturn',
    'Jupiter',
  ];

  /// Own signs and exaltation sign for the five Mahapurusha planets.
  static const Map<String, Set<int>> _dignified = {
    'Mars': {0, 7, 9},
    'Mercury': {2, 5},
    'Jupiter': {8, 11, 3},
    'Venus': {1, 6, 11},
    'Saturn': {9, 10, 6},
  };

  static const Map<String, YogaId> _mahapurusha = {
    'Mars': YogaId.ruchaka,
    'Mercury': YogaId.bhadra,
    'Jupiter': YogaId.hamsa,
    'Venus': YogaId.malavya,
    'Saturn': YogaId.shasha,
  };

  static const Set<int> _kendras = {1, 4, 7, 10};

  List<YogaResult> call(Kundali kundali) {
    final lagna = zodiacSignIndex(kundali.ascendant);
    if (lagna < 0) {
      throw ArgumentError('Unknown ascendant sign: "${kundali.ascendant}".');
    }

    final signs = <String, int>{};
    for (final PlanetPosition p in kundali.planets) {
      final index = zodiacSignIndex(p.sign);
      if (index >= 0) signs[p.planet] = index;
    }
    for (final name in _order.take(7)) {
      if (!signs.containsKey(name)) {
        throw ArgumentError('Kundali is missing $name.');
      }
    }

    int houseOf(String planet) => houseFrom(lagna, signs[planet]!);
    String lordOf(int house) => signLords[(lagna + house - 1) % 12];
    bool together(String a, String b) => a != b && signs[a] == signs[b];
    List<String> ordered(Iterable<String> names) => [
      for (final n in _order)
        if (names.contains(n)) n,
    ];

    final results = <YogaResult>[];
    final moon = signs['Moon']!;

    // Gajakesari: Jupiter in a kendra from the Moon.
    if (_kendras.contains(houseFrom(moon, signs['Jupiter']!))) {
      results.add(
        const YogaResult(id: YogaId.gajakesari, planets: ['Moon', 'Jupiter']),
      );
    }

    // Budhaditya: Sun and Mercury together.
    if (together('Sun', 'Mercury')) {
      results.add(
        const YogaResult(id: YogaId.budhaditya, planets: ['Sun', 'Mercury']),
      );
    }

    // Chandra-Mangal: Moon and Mars together.
    if (together('Moon', 'Mars')) {
      results.add(
        const YogaResult(id: YogaId.chandraMangal, planets: ['Moon', 'Mars']),
      );
    }

    // Pancha Mahapurusha: planet in own/exalted sign in a kendra from Lagna.
    for (final entry in _mahapurusha.entries) {
      final planet = entry.key;
      if (_dignified[planet]!.contains(signs[planet]) &&
          _kendras.contains(houseOf(planet))) {
        results.add(YogaResult(id: entry.value, planets: [planet]));
      }
    }

    // Raj yoga: a kendra lord joined by a different trikona lord.
    final kendraLords = {for (final h in _kendras) lordOf(h)};
    final trikonaLords = {for (final h in const [1, 5, 9]) lordOf(h)};
    final raj = <String>{};
    for (final k in kendraLords) {
      for (final t in trikonaLords) {
        if (together(k, t)) raj.addAll([k, t]);
      }
    }
    if (raj.isNotEmpty) {
      results.add(YogaResult(id: YogaId.rajYoga, planets: ordered(raj)));
    }

    // Yogakaraka: one planet ruling both a kendra (4/7/10) and a trikona
    // (5/9) for this Lagna.
    for (final planet in _order.take(7)) {
      final ruled = {
        for (var h = 1; h <= 12; h++)
          if (lordOf(h) == planet) h,
      };
      if (ruled.intersection({4, 7, 10}).isNotEmpty &&
          ruled.intersection({5, 9}).isNotEmpty) {
        results.add(YogaResult(id: YogaId.yogakaraka, planets: [planet]));
      }
    }

    // Dhana yoga: lord of the 2nd or 11th joined by a different lord of
    // the 1st, 5th or 9th.
    final wealthLords = {lordOf(2), lordOf(11)};
    final fortuneLords = {lordOf(1), lordOf(5), lordOf(9)};
    final dhana = <String>{};
    for (final w in wealthLords) {
      for (final f in fortuneLords) {
        if (together(w, f)) dhana.addAll([w, f]);
      }
    }
    if (together(lordOf(2), lordOf(11))) {
      dhana.addAll([lordOf(2), lordOf(11)]);
    }
    if (dhana.isNotEmpty) {
      results.add(YogaResult(id: YogaId.dhanaYoga, planets: ordered(dhana)));
    }

    // Viparita Raj yoga: a lord of 6, 8 or 12 placed in 6, 8 or 12.
    const dusthanas = {6, 8, 12};
    final viparita = {
      for (final h in dusthanas)
        if (dusthanas.contains(houseOf(lordOf(h)))) lordOf(h),
    };
    if (viparita.isNotEmpty) {
      results.add(
        YogaResult(id: YogaId.viparitaRajYoga, planets: ordered(viparita)),
      );
    }

    // Amala: a natural benefic in the 10th from Lagna or from the Moon.
    final amala = {
      for (final b in const ['Mercury', 'Jupiter', 'Venus'])
        if (houseOf(b) == 10 || houseFrom(moon, signs[b]!) == 10) b,
    };
    if (amala.isNotEmpty) {
      results.add(YogaResult(id: YogaId.amala, planets: ordered(amala)));
    }

    // Kemadruma: no planet (other than Sun, Rahu, Ketu) in the 2nd or 12th
    // from the Moon. Cancelled when such a planet is in a kendra from the
    // Moon, or the Moon itself is in a kendra from Lagna.
    const counted = ['Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];
    final flanked = counted.any((p) {
      final h = houseFrom(moon, signs[p]!);
      return h == 2 || h == 12;
    });
    if (!flanked) {
      final cancelled =
          _kendras.contains(houseOf('Moon')) ||
          counted.any((p) => _kendras.contains(houseFrom(moon, signs[p]!)));
      results.add(
        YogaResult(
          id: YogaId.kemadruma,
          planets: const ['Moon'],
          cancelled: cancelled,
        ),
      );
    }

    return results;
  }
}
