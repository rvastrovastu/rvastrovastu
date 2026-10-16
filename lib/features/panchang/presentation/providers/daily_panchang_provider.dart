import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/swiss_ephemeris_daily_panchang_repository.dart';
import '../../domain/entities/daily_panchang.dart';
import '../../domain/entities/daily_panchang_input.dart';
import '../../domain/repositories/daily_panchang_repository.dart';

final dailyPanchangRepositoryProvider = Provider<DailyPanchangRepository>((
  ref,
) {
  return SwissEphemerisDailyPanchangRepository();
});

final dailyPanchangProvider =
    FutureProvider.family<DailyPanchang, DailyPanchangInput>((
      ref,
      input,
    ) async {
      debugPrint('[PANCHANG][PROVIDER] CALLED');
      debugPrint(
        '[PANCHANG][PROVIDER] '
        'date=${input.date} '
        'lat=${input.latitude} '
        'lng=${input.longitude} '
        'tz=${input.timezone}',
      );

      final repository = ref.watch(dailyPanchangRepositoryProvider);

      debugPrint('[PANCHANG][PROVIDER] REPOSITORY READY');

      try {
        final result = await repository.calculate(
          date: input.date,
          latitude: input.latitude,
          longitude: input.longitude,
          timezone: input.timezone,
        );

        debugPrint(
          '[PANCHANG][PROVIDER] SUCCESS '
          'tithi=${result.tithi} '
          'nakshatra=${result.nakshatra} '
          'yoga=${result.yoga} '
          'sunrise=${result.sunrise} '
          'sunset=${result.sunset}',
        );

        return result;
      } catch (error, stack) {
        debugPrint('[PANCHANG][PROVIDER] ERROR: $error');
        debugPrint('[PANCHANG][PROVIDER] STACK: $stack');
        rethrow;
      }
    });
