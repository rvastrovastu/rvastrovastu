import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/app_clock_provider.dart';
import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../../dasha/domain/entities/dasha_birth_data.dart';
import '../../../dasha/presentation/providers/dasha_provider.dart';
import '../../../your_day/presentation/your_day_provider.dart';
import '../../domain/entities/daily_horoscope.dart';
import '../../domain/usecases/generate_daily_horoscope.dart';

final dailyHoroscopeGeneratorProvider = Provider<GenerateDailyHoroscope>((ref) {
  return GenerateDailyHoroscope();
});

// Updates when the calendar day changes, not every clock tick.
final dailyHoroscopeDateProvider = Provider<DateTime>((ref) {
  final now = ref.watch(dashaReferenceDateProvider);
  return DateTime(now.year, now.month, now.day);
});

/// The current ten-minute slot; the reading follows the Moon as it moves
/// into a new nakshatra or sign during the day.
final horoscopeMoonKeyProvider = Provider<DateTime>((ref) {
  return moonKey(ref.watch(appClockProvider));
});

final dailyHoroscopeProvider = FutureProvider.autoDispose<DailyHoroscope?>((
  ref,
) async {
  final profile = ref.watch(birthProfileProvider);
  if (profile == null) return null;

  final kundali = await ref.watch(kundaliProvider.future);
  if (kundali == null) return null;

  final dashaBirthData = DashaBirthData(
    birthDate: profile.dateOfBirth,
    moonLongitude: kundali.moonLongitude,
  );
  final mahadasha = ref.watch(currentDashaProvider(dashaBirthData));
  final antardasha = ref.watch(currentAntardashaProvider(dashaBirthData));
  final date = ref.watch(dailyHoroscopeDateProvider);
  final moon = await ref.watch(
    moonNowProvider(ref.watch(horoscopeMoonKeyProvider)).future,
  );

  return ref
      .watch(dailyHoroscopeGeneratorProvider)
      .call(
        natalMoonLongitude: kundali.moonLongitude,
        transitMoonLongitude: moon.longitude,
        mahadasha: mahadasha,
        antardasha: antardasha,
        date: date,
      );
});
