import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/daily_loop.dart';

/// What the user has done in the daily loop, kept on the device.
class DailyLoopRecord {
  /// Days ('yyyy-mm-dd') the daily remedy was done.
  final Set<String> remedyDays;

  /// Night check-in answers by day.
  final Map<String, CheckIn> checkIns;

  const DailyLoopRecord({
    this.remedyDays = const {},
    this.checkIns = const {},
  });

  DailyLoopRecord copyWith({
    Set<String>? remedyDays,
    Map<String, CheckIn>? checkIns,
  }) => DailyLoopRecord(
    remedyDays: remedyDays ?? this.remedyDays,
    checkIns: checkIns ?? this.checkIns,
  );
}

class DailyLoopStorage {
  static const _remedy = 'daily_loop_remedy_days';
  static const _checkIns = 'daily_loop_check_ins';

  /// Older days are dropped; streaks and match rates only look back
  /// this far.
  static const keepDays = 400;

  const DailyLoopStorage();

  Future<DailyLoopRecord> load() async {
    final prefs = await SharedPreferences.getInstance();
    final checkIns = <String, CheckIn>{};
    try {
      final raw = prefs.getString(_checkIns);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final answer = CheckIn.values.asNameMap()[entry.value];
          if (answer != null) checkIns[entry.key] = answer;
        }
      }
    } on FormatException {
      // Corrupt data: start again.
    }
    return DailyLoopRecord(
      remedyDays: (prefs.getStringList(_remedy) ?? const []).toSet(),
      checkIns: checkIns,
    );
  }

  Future<void> save(DailyLoopRecord record, DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    final oldest = dayKey(
      DateTime(today.year, today.month, today.day - keepDays),
    );
    bool keep(String day) => day.compareTo(oldest) >= 0;

    await prefs.setStringList(_remedy, [
      for (final day in record.remedyDays)
        if (keep(day)) day,
    ]..sort());
    await prefs.setString(
      _checkIns,
      jsonEncode({
        for (final entry in record.checkIns.entries)
          if (keep(entry.key)) entry.key: entry.value.name,
      }),
    );
  }
}
