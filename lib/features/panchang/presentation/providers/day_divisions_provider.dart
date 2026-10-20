import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/repositories/swiss_ephemeris_sun_times_repository.dart';
import '../../domain/entities/day_divisions.dart';
import '../../domain/entities/daily_panchang_input.dart';

final sunTimesRepositoryProvider = Provider<SwissEphemerisSunTimesRepository>(
  (ref) => SwissEphemerisSunTimesRepository(),
);

/// Choghadiya, Hora, Yamaganda and Gulika for the Vedic day that starts at
/// sunrise on [DailyPanchangInput.date]; null where the Sun does not rise.
final dayDivisionsProvider =
    FutureProvider.family<DayDivisions?, DailyPanchangInput>((
      ref,
      input,
    ) async {
      final sun = await ref
          .watch(sunTimesRepositoryProvider)
          .sunTimes(
            date: input.date,
            latitude: input.latitude,
            longitude: input.longitude,
            timezone: input.timezone,
          );
      if (sun == null) return null;

      final location = tz.getLocation(input.timezone);
      final weekday = tz.TZDateTime.from(sun.sunrise, location).weekday;
      return DayDivisions.calculate(sun, weekday);
    });
