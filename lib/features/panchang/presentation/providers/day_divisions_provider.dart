import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/repositories/swiss_ephemeris_sun_times_repository.dart';
import '../../domain/entities/daily_panchang_input.dart';
import '../../domain/entities/day_divisions.dart';

final sunTimesRepositoryProvider = Provider<SwissEphemerisSunTimesRepository>(
  (ref) => SwissEphemerisSunTimesRepository(),
);

/// The Vedic days that started at sunrise yesterday and today; either is
/// null where the Sun does not rise.
class VedicDays {
  final DayDivisions? yesterday;
  final DayDivisions? today;

  const VedicDays({required this.yesterday, required this.today});

  /// The Vedic day running at [now]: before today's sunrise that is
  /// yesterday's (its night is still going on).
  ({DayDivisions day, bool beforeSunrise})? at(DateTime now) {
    final t = today;
    if (t != null && !now.toUtc().isBefore(t.sun.sunrise)) {
      return (day: t, beforeSunrise: false);
    }
    final y = yesterday;
    if (y != null && y.sun.contains(now)) {
      return (day: y, beforeSunrise: true);
    }
    return t == null ? null : (day: t, beforeSunrise: false);
  }
}

/// Choghadiya, Hora, Yamaganda and Gulika around [DailyPanchangInput.date]
/// (the place's local calendar date).
final dayDivisionsProvider =
    FutureProvider.family<VedicDays, DailyPanchangInput>((ref, input) async {
      final repository = ref.watch(sunTimesRepositoryProvider);
      final location = tz.getLocation(input.timezone);

      Future<DayDivisions?> forDate(DateTime date) async {
        final sun = await repository.sunTimes(
          date: date,
          latitude: input.latitude,
          longitude: input.longitude,
          timezone: input.timezone,
        );
        if (sun == null) return null;
        final weekday = tz.TZDateTime.from(sun.sunrise, location).weekday;
        return DayDivisions.calculate(sun, weekday);
      }

      final date = input.date;
      final yesterday = await forDate(
        DateTime(date.year, date.month, date.day - 1),
      );
      final today = await forDate(DateTime(date.year, date.month, date.day));
      return VedicDays(yesterday: yesterday, today: today);
    });
