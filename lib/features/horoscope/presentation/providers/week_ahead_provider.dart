import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../../dasha/domain/entities/dasha_birth_data.dart';
import '../../../dasha/presentation/providers/dasha_provider.dart';
import '../../../your_day/presentation/your_day_provider.dart';
import '../../domain/entities/daily_horoscope.dart';
import 'daily_horoscope_provider.dart';

/// One horoscope for each of the next [days] days, starting today. The Moon
/// is read at 6 AM on each day, so each reading uses that day's Moon.
final weekAheadProvider = FutureProvider.autoDispose
    .family<List<DailyHoroscope>, int>((ref, days) async {
  final profile = ref.watch(birthProfileProvider);
  if (profile == null) return const [];

  final kundali = await ref.watch(kundaliProvider.future);
  if (kundali == null) return const [];

  final dashaBirthData = DashaBirthData(
    birthDate: profile.dateOfBirth,
    moonLongitude: kundali.moonLongitude,
  );
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
