import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/swiss_ephemeris_moon_repository.dart';
import '../domain/day_strength.dart';

final moonRepositoryProvider = Provider<SwissEphemerisMoonRepository>(
  (ref) => SwissEphemerisMoonRepository(),
);

/// The Moon at [instant]. Callers round the instant (to ten minutes) so
/// the Moon is recalculated a few times an hour, not on every clock tick.
final moonNowProvider = FutureProvider.autoDispose.family<MoonNow, DateTime>(
  (ref, instant) => ref.watch(moonRepositoryProvider).moonAt(instant),
);

/// [now] rounded down to ten minutes, in UTC.
DateTime moonKey(DateTime now) {
  final utc = now.toUtc();
  return DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute - utc.minute % 10,
  );
}
