import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../../dasha/domain/usecases/calculate_current_dasha.dart';
import '../../../dasha/presentation/providers/dasha_provider.dart';
import '../../../your_day/presentation/your_day_provider.dart';
import '../../domain/entities/daily_horoscope.dart';
import 'daily_horoscope_provider.dart';
import 'package:rv_astro_vastu/features/dasha/domain/dasha_birth_instant.dart';

/// One horoscope for each of the next [days] days, starting today. The Moon
/// is read at 6 AM on each day, so each reading uses that day's Moon.
final weekAheadProvider = FutureProvider.autoDispose
    .family<List<DailyHoroscope>, int>((ref, days) async {
  final profile = ref.watch(birthProfileProvider);
  if (profile == null) return const [];

  final kundali = await ref.watch(kundaliProvider.future);
  if (kundali == null) return const [];

  final dashaBirthData = dashaBirthDataFor(profile, kundali);
  final mahadasha = ref.watch(currentDashaProvider(dashaBirthData));
  final antardasha = ref.watch(currentAntardashaProvider(dashaBirthData));
  final today = ref.watch(dailyHoroscopeDateProvider);
  final generator = ref.watch(dailyHoroscopeGeneratorProvider);

  final results = <DailyHoroscope>[];
  for (var i = 0; i < days; i++) {
    final date = DateTime(today.year, today.month, today.day + i);
    final moon = await ref.watch(
      moonNowProvider(moonKey(DateTime(date.year, date.month, date.day, 6)))
          .future,
    );
    results.add(
      generator.call(
        natalMoonLongitude: kundali.moonLongitude,
        transitMoonLongitude: moon.longitude,
        mahadasha: mahadasha,
        antardasha: antardasha,
        date: date,
      ),
    );
  }
  return results;
});

/// The readings of the past [days] days, newest first, starting yesterday.
///
/// Each past day is recalculated from the chart (nothing is stored): that
/// day's Moon at 6 AM and the dasha periods running on that day, so a day
/// reads the same as it did when it was "today".
final pastDaysProvider = FutureProvider.autoDispose
    .family<List<DailyHoroscope>, int>((ref, days) async {
      final profile = ref.watch(birthProfileProvider);
      if (profile == null) return const [];

      final kundali = await ref.watch(kundaliProvider.future);
      if (kundali == null) return const [];

      final timeline = ref.watch(
        dashaTimelineProvider(dashaBirthDataFor(profile, kundali)),
      );
      final today = ref.watch(dailyHoroscopeDateProvider);
      final generator = ref.watch(dailyHoroscopeGeneratorProvider);

      final results = <DailyHoroscope>[];
      for (var i = 1; i <= days; i++) {
        final date = DateTime(today.year, today.month, today.day - i);
        final morning = DateTime(date.year, date.month, date.day, 6);
        final dasha = CalculateCurrentDasha().call(
          timeline: timeline,
          date: morning,
        );
        final moon = await ref.watch(moonNowProvider(moonKey(morning)).future);
        results.add(
          generator.call(
            natalMoonLongitude: kundali.moonLongitude,
            transitMoonLongitude: moon.longitude,
            mahadasha: dasha.mahadasha,
            antardasha: dasha.antardasha,
            date: date,
          ),
        );
      }
      return results;
    });
