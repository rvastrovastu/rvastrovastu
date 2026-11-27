import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/domain/entities/planet_position.dart';
import '../../../dosha/domain/entities/zodiac_signs.dart';
import '../entities/yoga.dart';

/// Detects widely used Parashari yogas with whole-sign houses.
///
/// Only conjunction-based forms are checked for Raj, Dhana and similar
/// lordship yogas; aspect variants are not, so the list errs on the side
/// of fewer, clearer results. Sign exchanges are reported on their own as
/// Parivartana yoga.
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
  static const Set<int> _kendrasAndTrikonas = {1, 4, 5, 7, 9, 10};

  /// Exaltation sign of each classical planet (debilitation is opposite).
  static const Map<String, int> exaltation = {
    'Sun': 0,
    'Moon': 1,
    'Mars': 9,
    'Mercury': 5,
    'Jupiter': 3,
    'Venus': 11,
    'Saturn': 6,
  };

  static const Map<String, Set<int>> ownSigns = {
    'Sun': {4},
    'Moon': {3},
    'Mars': {0, 7},
    'Mercury': {2, 5},
    'Jupiter': {8, 11},
    'Venus': {1, 6},
    'Saturn': {9, 10},
  };

  static const List<String> _benefics = ['Mercury', 'Jupiter', 'Venus'];
  static const List<String> _malefics = [
    'Sun',
    'Mars',
    'Saturn',
    'Rahu',
    'Ketu',
  ];

  /// Planets counted around the Moon and Sun (no luminaries or nodes).
  static const List<String> _starPlanets = [
    'Mars',
    'Mercury',
    'Jupiter',
    'Venus',
    'Saturn',
  ];

  static const List<YogaId> _sankhya = [
    YogaId.gola,
    YogaId.yuga,
    YogaId.shoola,
    YogaId.kedara,
    YogaId.pasha,
    YogaId.dama,
    YogaId.veena,
  ];

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

    // ---- Planets around the Moon: Sunapha, Anapha, Durudhara.
    List<String> fromMoon(int house) => [
      for (final p in _starPlanets)
        if (houseFrom(moon, signs[p]!) == house) p,
    ];
    final secondFromMoon = fromMoon(2);
    final twelfthFromMoon = fromMoon(12);
    if (secondFromMoon.isNotEmpty && twelfthFromMoon.isNotEmpty) {
      results.add(
        YogaResult(
          id: YogaId.durudhara,
          planets: ordered([...secondFromMoon, ...twelfthFromMoon]),
        ),
      );
    } else if (secondFromMoon.isNotEmpty) {
      results.add(YogaResult(id: YogaId.sunapha, planets: secondFromMoon));
    } else if (twelfthFromMoon.isNotEmpty) {
      results.add(YogaResult(id: YogaId.anapha, planets: twelfthFromMoon));
    }

    // ---- Planets around the Sun: Vesi, Vasi, Ubhayachari.
    final sun = signs['Sun']!;
    List<String> fromSun(int house) => [
      for (final p in _starPlanets)
        if (houseFrom(sun, signs[p]!) == house) p,
    ];
    final secondFromSun = fromSun(2);
    final twelfthFromSun = fromSun(12);
    if (secondFromSun.isNotEmpty && twelfthFromSun.isNotEmpty) {
      results.add(
        YogaResult(
          id: YogaId.ubhayachari,
          planets: ordered([...secondFromSun, ...twelfthFromSun]),
        ),
      );
    } else if (secondFromSun.isNotEmpty) {
      results.add(YogaResult(id: YogaId.vesi, planets: secondFromSun));
    } else if (twelfthFromSun.isNotEmpty) {
      results.add(YogaResult(id: YogaId.vasi, planets: twelfthFromSun));
    }

    // ---- Adhi: at least two benefics in the 6th, 7th or 8th from the Moon.
    final adhi = [
      for (final b in _benefics)
        if (const {6, 7, 8}.contains(houseFrom(moon, signs[b]!))) b,
    ];
    if (adhi.length >= 2) {
      results.add(YogaResult(id: YogaId.adhi, planets: adhi));
    }

    // ---- Vasumati: at least two benefics in upachayas (3, 6, 10, 11)
    // from the Moon.
    final vasumati = [
      for (final b in _benefics)
        if (const {3, 6, 10, 11}.contains(houseFrom(moon, signs[b]!))) b,
    ];
    if (vasumati.length >= 2) {
      results.add(YogaResult(id: YogaId.vasumati, planets: vasumati));
    }

    // ---- Shakata: Moon in the 6th or 8th from Jupiter. Cancelled when
    // the Moon is in a kendra from Lagna.
    if (const {6, 8}.contains(houseFrom(signs['Jupiter']!, moon))) {
      results.add(
        YogaResult(
          id: YogaId.shakata,
          planets: const ['Moon', 'Jupiter'],
          cancelled: _kendras.contains(houseOf('Moon')),
        ),
      );
    }

    bool dignified(String planet) =>
        exaltation[planet] == signs[planet] ||
        (ownSigns[planet]?.contains(signs[planet]) ?? false);
    bool exalted(String planet) => exaltation[planet] == signs[planet];
    bool debilitated(String planet) =>
        exaltation.containsKey(planet) &&
        (exaltation[planet]! + 6) % 12 == signs[planet];

    // ---- Lakshmi: 9th lord in its own or exaltation sign in a kendra or
    // trikona, with the Lagna lord also in a kendra or trikona.
    final lord1 = lordOf(1);
    final lord9 = lordOf(9);
    if (dignified(lord9) &&
        _kendrasAndTrikonas.contains(houseOf(lord9)) &&
        _kendrasAndTrikonas.contains(houseOf(lord1))) {
      results.add(
        YogaResult(id: YogaId.lakshmi, planets: ordered({lord9, lord1})),
      );
    }

    // ---- Saraswati: Mercury, Jupiter and Venus all in kendras, trikonas
    // or the 2nd house, with Jupiter not debilitated.
    const saraswatiHouses = {1, 2, 4, 5, 7, 9, 10};
    if (_benefics.every((b) => saraswatiHouses.contains(houseOf(b))) &&
        !debilitated('Jupiter')) {
      results.add(const YogaResult(id: YogaId.saraswati, planets: _benefics));
    }

    // ---- Chamara: the Lagna lord exalted in a kendra.
    if (exalted(lord1) && _kendras.contains(houseOf(lord1))) {
      results.add(YogaResult(id: YogaId.chamara, planets: [lord1]));
    }

    // ---- Kahala: lords of the 4th and 9th in kendras from each other,
    // with the Lagna lord in a kendra or trikona.
    final lord4 = lordOf(4);
    if (lord4 != lord9 &&
        _kendras.contains(houseFrom(signs[lord4]!, signs[lord9]!)) &&
        _kendrasAndTrikonas.contains(houseOf(lord1))) {
      results.add(
        YogaResult(id: YogaId.kahala, planets: ordered({lord4, lord9})),
      );
    }

    // ---- Parvata: a benefic in a kendra, and no malefic in the 6th or
    // 8th.
    final beneficInKendra = [
      for (final b in _benefics)
        if (_kendras.contains(houseOf(b))) b,
    ];
    final maleficIn6or8 = _malefics.any(
      (m) => signs.containsKey(m) && const {6, 8}.contains(houseOf(m)),
    );
    if (beneficInKendra.isNotEmpty && !maleficIn6or8) {
      results.add(YogaResult(id: YogaId.parvata, planets: beneficInKendra));
    }

    // ---- Dharma-Karmadhipati: lords of the 9th and 10th together, or in
    // each other's signs.
    final lord10 = lordOf(10);
    if (lord9 != lord10 &&
        (together(lord9, lord10) ||
            (signLords[signs[lord9]!] == lord10 &&
                signLords[signs[lord10]!] == lord9))) {
      results.add(
        YogaResult(
          id: YogaId.dharmaKarmadhipati,
          planets: ordered({lord9, lord10}),
        ),
      );
    }

    // ---- Neecha Bhanga Raj: a debilitated planet whose debilitation is
    // cancelled because the lord of its sign, or the lord of its
    // exaltation sign, is in a kendra from Lagna or from the Moon.
    bool inKendra(String planet) =>
        _kendras.contains(houseOf(planet)) ||
        _kendras.contains(houseFrom(moon, signs[planet]!));
    final neechaBhanga = [
      for (final p in _order.take(7))
        if (debilitated(p) &&
            (inKendra(signLords[signs[p]!]) ||
                inKendra(signLords[exaltation[p]!])))
          p,
    ];
    if (neechaBhanga.isNotEmpty) {
      results.add(
        YogaResult(id: YogaId.neechaBhangaRaj, planets: neechaBhanga),
      );
    }

    // ---- Parivartana: two planets in each other's signs.
    final exchanged = <String>{};
    final classical = _order.take(7).toList();
    for (var i = 0; i < classical.length; i++) {
      for (var j = i + 1; j < classical.length; j++) {
        final a = classical[i];
        final b = classical[j];
        if (signLords[signs[a]!] == b && signLords[signs[b]!] == a) {
          exchanged.addAll([a, b]);
        }
      }
    }
    if (exchanged.isNotEmpty) {
      results.add(
        YogaResult(id: YogaId.parivartana, planets: ordered(exchanged)),
      );
    }

    // ---- Kartari: the Lagna hemmed by benefics (Shubha) or by malefics
    // (Papa) in the 2nd and 12th.
    List<String> inHouse(List<String> group, int house) => [
      for (final p in group)
        if (signs.containsKey(p) && houseOf(p) == house) p,
    ];
    final benefic2 = inHouse(_benefics, 2);
    final benefic12 = inHouse(_benefics, 12);
    if (benefic2.isNotEmpty && benefic12.isNotEmpty) {
      results.add(
        YogaResult(
          id: YogaId.shubhaKartari,
          planets: ordered([...benefic2, ...benefic12]),
        ),
      );
    }
    final malefic2 = inHouse(_malefics, 2);
    final malefic12 = inHouse(_malefics, 12);
    if (malefic2.isNotEmpty && malefic12.isNotEmpty) {
      results.add(
        YogaResult(
          id: YogaId.papaKartari,
          planets: ordered([...malefic2, ...malefic12]),
        ),
      );
    }

    // ---- Chatussagara: all four kendras occupied.
    if (_kendras.every((h) => classical.any((p) => houseOf(p) == h))) {
      results.add(
        YogaResult(
          id: YogaId.chatussagara,
          planets: ordered(
            classical.where((p) => _kendras.contains(houseOf(p))),
          ),
        ),
      );
    }

    // ---- Viparita Raj yogas by name: Harsha (6th lord), Sarala (8th
    // lord), Vimala (12th lord) placed in the 6th, 8th or 12th.
    for (final (house, id) in const [
      (6, YogaId.harsha),
      (8, YogaId.sarala),
      (12, YogaId.vimala),
    ]) {
      final lord = lordOf(house);
      if (dusthanas.contains(houseOf(lord))) {
        results.add(YogaResult(id: id, planets: [lord]));
      }
    }

    // ---- Conjunctions.
    bool withNode(String planet, String node) =>
        signs.containsKey(node) && together(planet, node);
    if (together('Jupiter', 'Mars')) {
      results.add(
        const YogaResult(id: YogaId.guruMangal, planets: ['Mars', 'Jupiter']),
      );
    }
    if (withNode('Jupiter', 'Rahu')) {
      results.add(
        const YogaResult(id: YogaId.guruChandal, planets: ['Jupiter', 'Rahu']),
      );
    }
    if (together('Moon', 'Saturn')) {
      results.add(
        const YogaResult(id: YogaId.vish, planets: ['Moon', 'Saturn']),
      );
    }
    if (withNode('Mars', 'Rahu')) {
      results.add(
        const YogaResult(id: YogaId.angarak, planets: ['Mars', 'Rahu']),
      );
    }

    // ---- Daridra: the 11th lord in the 6th, 8th or 12th.
    final lord11 = lordOf(11);
    if (dusthanas.contains(houseOf(lord11))) {
      results.add(YogaResult(id: YogaId.daridra, planets: [lord11]));
    }

    // ---- Sankhya: number of signs the seven planets occupy.
    final occupied = {for (final p in classical) signs[p]!}.length;
    results.add(YogaResult(id: _sankhya[occupied - 1], planets: classical));

    return results;
  }
}
