import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../astrology/presentation/providers/astrology_provider.dart';
import '../../dosha/domain/entities/zodiac_signs.dart';
import '../../gochar/presentation/providers/gochar_provider.dart';
import '../data/sky_repository.dart';
import '../domain/rashifal.dart';

final skyRepositoryProvider = Provider<SkyRepository>(
  (ref) => SwissEphemerisSkyRepository(),
);

/// Today's local date, read once.
final rashifalTodayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// The active profile's Moon sign (Aries = 0), or null without one.
final userMoonSignProvider = FutureProvider<int?>((ref) async {
  final kundali = await ref.watch(kundaliProvider.future);
  if (kundali == null) return null;
  final index = zodiacSignIndex(kundali.moonSign);
  return index < 0 ? null : index;
});

typedef RashifalKey = ({int sign, RashifalPeriod period, DateTime day});

final rashifalProvider = FutureProvider.family<Rashifal, RashifalKey>((
  ref,
  key,
) async {
  const engine = RashifalEngine();
  final sky = ref.watch(skyRepositoryProvider);
  final day = DateTime(key.day.year, key.day.month, key.day.day);
  DateTime noon(DateTime d, [int plus = 0]) =>
      DateTime(d.year, d.month, d.day + plus, 12);

  switch (key.period) {
    case RashifalPeriod.daily:
      final snapshot = (await sky.snapshots([noon(day)])).single;
      return engine.daily(key.sign, day, snapshot);
    case RashifalPeriod.weekly:
      final monday = RashifalEngine.weekStart(day);
      final days = await sky.snapshots([
        for (var i = 0; i < 7; i++) noon(monday, i),
      ]);
      return engine.weekly(key.sign, monday, days);
    case RashifalPeriod.monthly:
      final first = DateTime(day.year, day.month);
      final count = DateTime(day.year, day.month + 1, 0).day;
      final days = await sky.snapshots([
        for (var i = 0; i < count; i++) noon(first, i),
      ]);
      return engine.monthly(key.sign, first, days);
    case RashifalPeriod.yearly:
      final periods = await ref
          .watch(transitRepositoryProvider)
          .signPeriods(
            fromUtc: DateTime.utc(day.year),
            toUtc: DateTime.utc(day.year + 1),
          );
      return engine.yearly(key.sign, day.year, periods);
  }
});
