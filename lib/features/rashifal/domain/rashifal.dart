import 'dart:math' as math;

import '../../dosha/domain/entities/zodiac_signs.dart';
import '../../gochar/domain/entities/transit.dart';

enum RashifalPeriod { daily, weekly, monthly, yearly }

enum LifeArea { love, career, money, health }

/// Sidereal sign (Aries = 0) of each planet at one moment, keyed by the
/// app's planet names ('Sun', 'Moon', …, 'Rahu', 'Ketu').
class SkySnapshot {
  final DateTime utc;
  final Map<String, int> signs;

  const SkySnapshot(this.utc, this.signs);

  int sign(String planet) => signs[planet]!;
}

/// A planet's transit counted from the Moon sign being read.
class TransitNote {
  final String planet;
  final int signIndex;
  final int house;
  final bool favourable;

  const TransitNote({
    required this.planet,
    required this.signIndex,
    required this.house,
    required this.favourable,
  });
}

/// A sign change during the period.
class RashifalIngress {
  final String planet;
  final int signIndex;
  final DateTime date;

  const RashifalIngress(this.planet, this.signIndex, this.date);
}

class Rashifal {
  /// Moon sign read, Aries = 0.
  final int sign;
  final RashifalPeriod period;

  /// First and last local day covered.
  final DateTime from;
  final DateTime to;

  /// 1–5 stars per area, and overall.
  final Map<LifeArea, int> stars;
  final int overall;

  /// Planets that shape the period, most important first.
  final List<TransitNote> notes;

  /// Daily only: the Moon's house from the sign.
  final int? moonHouse;

  /// Weekly and monthly: days the Moon is favourable for the sign.
  final List<DateTime> goodDays;

  /// Daily only: lucky planet (gives the colour and number).
  final String? luckyPlanet;

  /// Yearly only: sign changes of the slow planets in the year.
  final List<RashifalIngress> ingresses;

  /// Saturn's house from the sign when it is 12, 1 or 2 (Sade Sati).
  final int? sadeSatiHouse;

  const Rashifal({
    required this.sign,
    required this.period,
    required this.from,
    required this.to,
    required this.stars,
    required this.overall,
    required this.notes,
    this.moonHouse,
    this.goodDays = const [],
    this.luckyPlanet,
    this.ingresses = const [],
    this.sadeSatiHouse,
  });
}

/// Rashifal from the Moon sign by classical Gochara (Phaladeepika): each
/// planet is favourable from certain houses counted from the Moon.
class RashifalEngine {
  const RashifalEngine();

  static const Map<String, Set<int>> favourableHouses = {
    'Sun': {3, 6, 10, 11},
    'Moon': {1, 3, 6, 7, 10, 11},
    'Mars': {3, 6, 11},
    'Mercury': {2, 4, 6, 8, 10, 11},
    'Jupiter': {2, 5, 7, 9, 11},
    'Venus': {1, 2, 3, 4, 5, 8, 9, 11, 12},
    'Saturn': {3, 6, 11},
    'Rahu': {3, 6, 11},
    'Ketu': {3, 6, 11},
  };

  /// Houses that speak for each area.
  static const Map<LifeArea, Set<int>> areaHouses = {
    LifeArea.love: {5, 7, 12},
    LifeArea.career: {3, 6, 10},
    LifeArea.money: {2, 11},
    LifeArea.health: {1, 6, 8},
  };

  /// Areas each planet signifies (karaka).
  static const Map<String, Set<LifeArea>> karaka = {
    'Sun': {LifeArea.career, LifeArea.health},
    'Moon': {LifeArea.health, LifeArea.love},
    'Mars': {LifeArea.career, LifeArea.health},
    'Mercury': {LifeArea.money, LifeArea.career},
    'Jupiter': {LifeArea.money, LifeArea.love},
    'Venus': {LifeArea.love, LifeArea.money},
    'Saturn': {LifeArea.career, LifeArea.health},
    'Rahu': {LifeArea.health},
    'Ketu': {LifeArea.health},
  };

  static const signLords = [
    'Mars', 'Venus', 'Mercury', 'Moon', 'Sun', 'Mercury', //
    'Venus', 'Mars', 'Jupiter', 'Saturn', 'Saturn', 'Jupiter',
  ];

  /// Lord of each weekday, Monday first (DateTime.monday = 1).
  static const weekdayLords = [
    'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', 'Sun', //
  ];

  static const Map<String, Set<String>> friends = {
    'Sun': {'Moon', 'Mars', 'Jupiter'},
    'Moon': {'Sun', 'Mercury'},
    'Mars': {'Sun', 'Moon', 'Jupiter'},
    'Mercury': {'Sun', 'Venus'},
    'Jupiter': {'Sun', 'Moon', 'Mars'},
    'Venus': {'Mercury', 'Saturn'},
    'Saturn': {'Mercury', 'Venus'},
  };

  static const Map<String, int> luckyNumbers = {
    'Sun': 1, 'Moon': 2, 'Jupiter': 3, 'Mercury': 5, //
    'Venus': 6, 'Saturn': 8, 'Mars': 9,
  };

  /// Colour key for the l10n `rashifalColour` select.
  static const Map<String, String> luckyColours = {
    'Sun': 'orange', 'Moon': 'white', 'Mars': 'red', 'Mercury': 'green', //
    'Jupiter': 'yellow', 'Venus': 'pink', 'Saturn': 'blue',
  };

  static int houseOf(int fromSign, int sign) => houseFrom(fromSign, sign);

  static bool isFavourable(String planet, int house) =>
      favourableHouses[planet]!.contains(house);

  TransitNote note(int sign, String planet, int planetSign) {
    final house = houseOf(sign, planetSign);
    return TransitNote(
      planet: planet,
      signIndex: planetSign,
      house: house,
      favourable: isFavourable(planet, house),
    );
  }

  /// Weighted area scores → stars. [weights] gives each planet's say.
  (Map<LifeArea, int>, int) _stars(
    List<(TransitNote, double)> weighted, {
    required double scale,
  }) {
    final stars = <LifeArea, int>{};
    for (final area in LifeArea.values) {
      var score = 0.0;
      for (final (n, w) in weighted) {
        final relevance =
            (karaka[n.planet]!.contains(area) ? 1 : 0) +
            (areaHouses[area]!.contains(n.house) ? 1 : 0);
        score += (n.favourable ? 1 : -1) * w * relevance;
      }
      stars[area] = (3 + (score / scale).round()).clamp(1, 5);
    }
    final overall = (stars.values.reduce((a, b) => a + b) / stars.length)
        .round()
        .clamp(1, 5);
    return (stars, overall);
  }

  static int? _sadeSati(int sign, int saturnSign) {
    final h = houseOf(sign, saturnSign);
    return h == 12 || h == 1 || h == 2 ? h : null;
  }

  Rashifal daily(int sign, DateTime day, SkySnapshot sky) {
    const order = ['Moon', 'Sun', 'Mars', 'Mercury', 'Venus'];
    final notes = [for (final p in order) note(sign, p, sky.sign(p))];
    final weights = {'Moon': 3.0, 'Sun': 1.0, 'Mars': 1.0, 'Mercury': 1.0};
    final (stars, overall) = _stars([
      for (final n in notes) (n, weights[n.planet] ?? 1.0),
    ], scale: 2.5);

    final lord = signLords[sign];
    final dayLord = weekdayLords[day.weekday - 1];
    final lucky = dayLord == lord || friends[lord]!.contains(dayLord)
        ? dayLord
        : lord;

    return Rashifal(
      sign: sign,
      period: RashifalPeriod.daily,
      from: day,
      to: day,
      stars: stars,
      overall: overall,
      notes: notes,
      moonHouse: notes.first.house,
      luckyPlanet: lucky,
      sadeSatiHouse: _sadeSati(sign, sky.sign('Saturn')),
    );
  }

  /// [days] = one snapshot per local day of the period, in order.
  Rashifal _span(
    int sign,
    RashifalPeriod period,
    List<SkySnapshot> days,
    DateTime from,
    DateTime to, {
    required Map<String, double> weights,
    required double scale,
    required int maxGoodDays,
  }) {
    final mid = days[days.length ~/ 2];
    final order = weights.keys.toList();
    final notes = [for (final p in order) note(sign, p, mid.sign(p))];
    final (stars, overall) = _stars([
      for (final n in notes) (n, weights[n.planet]!),
    ], scale: scale);

    final good = <DateTime>[];
    for (final (i, d) in days.indexed) {
      if (isFavourable('Moon', houseOf(sign, d.sign('Moon')))) {
        good.add(DateTime(from.year, from.month, from.day + i));
      }
    }

    return Rashifal(
      sign: sign,
      period: period,
      from: from,
      to: to,
      stars: stars,
      overall: overall,
      notes: notes,
      goodDays: good.take(maxGoodDays).toList(),
      sadeSatiHouse: _sadeSati(sign, mid.sign('Saturn')),
    );
  }

  Rashifal weekly(int sign, DateTime monday, List<SkySnapshot> days) => _span(
    sign,
    RashifalPeriod.weekly,
    days,
    monday,
    DateTime(monday.year, monday.month, monday.day + 6),
    weights: const {'Sun': 2, 'Mars': 2, 'Mercury': 1.5, 'Venus': 1.5},
    scale: 2.5,
    maxGoodDays: 7,
  );

  Rashifal monthly(int sign, DateTime first, List<SkySnapshot> days) => _span(
    sign,
    RashifalPeriod.monthly,
    days,
    first,
    DateTime(first.year, first.month + 1, 0),
    weights: const {
      'Sun': 2,
      'Mars': 2,
      'Jupiter': 1.5,
      'Venus': 1.5,
      'Mercury': 1,
    },
    scale: 3,
    maxGoodDays: 8,
  );

  /// [periods] = the slow planets' sign periods covering the year.
  Rashifal yearly(
    int sign,
    int year,
    Map<TransitPlanet, List<PlanetSignPeriod>> periods,
  ) {
    final start = DateTime.utc(year);
    final end = DateTime.utc(year + 1);
    final yearMs = end.difference(start).inMilliseconds;
    const weights = {
      TransitPlanet.jupiter: 3.0,
      TransitPlanet.saturn: 3.0,
      TransitPlanet.rahu: 1.5,
      TransitPlanet.ketu: 1.5,
    };

    final weighted = <(TransitNote, double)>[];
    final notes = <TransitNote>[];
    final ingresses = <RashifalIngress>[];
    int? saturnMain;

    for (final planet in TransitPlanet.values) {
      var longest = 0;
      TransitNote? main;
      for (final p in periods[planet] ?? const <PlanetSignPeriod>[]) {
        final s = p.start.isAfter(start) ? p.start : start;
        final e = p.end.isBefore(end) ? p.end : end;
        if (!e.isAfter(s)) continue;
        final share = e.difference(s).inMilliseconds;
        final n = note(sign, planet.displayKey, p.signIndex);
        weighted.add((n, weights[planet]! * share / yearMs));
        if (share > longest) {
          longest = share;
          main = n;
          if (planet == TransitPlanet.saturn) saturnMain = p.signIndex;
        }
        if (p.start.isAfter(start) && p.start.isBefore(end)) {
          ingresses.add(
            RashifalIngress(planet.displayKey, p.signIndex, p.start),
          );
        }
      }
      if (main != null) notes.add(main);
    }
    ingresses.sort((a, b) => a.date.compareTo(b.date));
    final (stars, overall) = _stars(weighted, scale: 2.5);

    return Rashifal(
      sign: sign,
      period: RashifalPeriod.yearly,
      from: DateTime(year),
      to: DateTime(year, 12, 31),
      stars: stars,
      overall: overall,
      notes: notes,
      ingresses: ingresses,
      sadeSatiHouse: saturnMain == null ? null : _sadeSati(sign, saturnMain),
    );
  }

  /// 'great', 'good', 'mixed' or 'careful' for [stars].
  static String level(int stars) => switch (stars) {
    >= 5 => 'great',
    4 => 'good',
    3 => 'mixed',
    _ => 'careful',
  };

  /// 'good', 'mixed' or 'careful' for an area.
  static String areaLevel(int stars) => switch (stars) {
    >= 4 => 'good',
    3 => 'mixed',
    _ => 'careful',
  };

  /// Monday of the week holding [day].
  static DateTime weekStart(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - 1));

  /// Number of days from [from] to [to], inclusive.
  static int dayCount(DateTime from, DateTime to) =>
      math.max(1, DateTime.utc(to.year, to.month, to.day)
              .difference(DateTime.utc(from.year, from.month, from.day))
              .inDays +
          1);
}
