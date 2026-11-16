// lib/features/numerology/domain/numerology_forecast.dart
//
// Forecast, compatibility and Lo Shu helpers built on the Chaldean [Numerology].

import 'numerology.dart';

/// How two birth numbers relate, using the traditional planetary friendship table.
enum NumberRelation { same, friend, neutral, challenging }

class NumerologyForecast {
  NumerologyForecast._();

  // Traditional Vedic planetary friendships. Simplified: sources differ slightly.
  static const Map<String, Set<String>> _friends = {
    'Sun': {'Moon', 'Mars', 'Jupiter'},
    'Moon': {'Sun', 'Mercury'},
    'Mars': {'Sun', 'Moon', 'Jupiter'},
    'Mercury': {'Sun', 'Venus'},
    'Jupiter': {'Sun', 'Moon', 'Mars'},
    'Venus': {'Mercury', 'Saturn'},
    'Saturn': {'Mercury', 'Venus', 'Rahu'},
    'Rahu': {'Mercury', 'Venus', 'Saturn'},
    'Ketu': {'Mars', 'Venus', 'Saturn'},
  };

  static const Map<String, Set<String>> _enemies = {
    'Sun': {'Venus', 'Saturn'},
    'Moon': {},
    'Mars': {'Mercury'},
    'Mercury': {'Moon'},
    'Jupiter': {'Mercury', 'Venus'},
    'Venus': {'Sun', 'Moon'},
    'Saturn': {'Sun', 'Moon', 'Mars'},
    'Rahu': {'Sun', 'Moon', 'Mars'},
    'Ketu': {'Sun', 'Moon'},
  };

  /// The tables are written one way round, so a pair counts as listed if
  /// either planet lists the other. Without this, relation(8, 9) and
  /// relation(9, 8) could disagree.
  static bool _listed(Map<String, Set<String>> table, String a, String b) =>
      (table[a]?.contains(b) ?? false) || (table[b]?.contains(a) ?? false);

  /// Relation between two numbers (1–9), by their ruling planets.
  /// Friend or enemy only when the pair is listed on one side and not
  /// contradicted on the other. Moon and Mercury are friends in one direction
  /// and enemies in the other, so they come out neutral.
  static NumberRelation relation(int a, int b) {
    if (a == b) return NumberRelation.same;
    final pa = Numerology.rulingPlanet[a] ?? '';
    final pb = Numerology.rulingPlanet[b] ?? '';
    final friend = _listed(_friends, pa, pb);
    final enemy = _listed(_enemies, pa, pb);
    if (friend && !enemy) return NumberRelation.friend;
    if (enemy && !friend) return NumberRelation.challenging;
    return NumberRelation.neutral;
  }

  /// Personal month: personal year + calendar month, reduced.
  static int personalMonth(int personalYear, int month) =>
      Numerology.reduce(personalYear + month);

  /// Personal day: personal month + calendar day, reduced.
  static int personalDay(int personalMonth, int day) =>
      Numerology.reduce(personalMonth + day);

  /// Upcoming days whose day-number is the same as or friendly to [mulank].
  static List<(DateTime, NumberRelation)> luckyDates({
    required int mulank,
    required DateTime from,
    int days = 30,
    int take = 5,
  }) {
    final result = <(DateTime, NumberRelation)>[];
    for (var i = 0; i < days && result.length < take; i++) {
      final day = DateTime(from.year, from.month, from.day + i);
      final rel = relation(mulank, Numerology.reduce(day.day));
      if (rel == NumberRelation.same || rel == NumberRelation.friend) {
        result.add((day, rel));
      }
    }
    return result;
  }

  /// How often each digit 1–9 appears in the birth date (zeros ignored).
  static Map<int, int> loShuCounts(DateTime dob) {
    final counts = {for (var i = 1; i <= 9; i++) i: 0};
    for (final ch in '${dob.day}${dob.month}${dob.year}'.split('')) {
      final d = int.parse(ch);
      if (d != 0) counts[d] = counts[d]! + 1;
    }
    return counts;
  }
}
