import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../../dasha/domain/entities/dasha_birth_data.dart';
import '../../../dasha/presentation/providers/dasha_provider.dart';
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

final dailyHoroscopeProvider = FutureProvider<DailyHoroscope?>((ref) async {
  debugPrint('============================================================');
  debugPrint('[HOROSCOPE][PROVIDER] CALLED');

  final profile = ref.watch(birthProfileProvider);

  if (profile == null) {
    debugPrint('[HOROSCOPE][PROVIDER] NO ACTIVE PROFILE');
    debugPrint('============================================================');
    return null;
  }

  final kundali = await ref.watch(kundaliProvider.future);

  if (kundali == null) {
    debugPrint('[HOROSCOPE][PROVIDER] NO KUNDALI');
    debugPrint('============================================================');
    return null;
  }

  final dashaBirthData = DashaBirthData(
    birthDate: profile.dateOfBirth,
    moonLongitude: kundali.moonLongitude,
  );

  final mahadasha = ref.watch(currentDashaProvider(dashaBirthData));
  final antardasha = ref.watch(currentAntardashaProvider(dashaBirthData));

  final generator = ref.watch(dailyHoroscopeGeneratorProvider);

  final date = ref.watch(dailyHoroscopeDateProvider);

  debugPrint('[HOROSCOPE][PROVIDER] PROFILE=${profile.name}');
  debugPrint('[HOROSCOPE][PROVIDER] MOON SIGN=${kundali.moonSign}');
  debugPrint('[HOROSCOPE][PROVIDER] NAKSHATRA=${kundali.nakshatra}');
  debugPrint(
    '[HOROSCOPE][PROVIDER] MAHADASHA=${mahadasha?.planet.name ?? 'Unknown'}',
  );
  debugPrint(
    '[HOROSCOPE][PROVIDER] ANTARDASHA=${antardasha?.planet.name ?? 'Unknown'}',
  );
  debugPrint('[HOROSCOPE][PROVIDER] GENERATING');

  final result = generator.call(
    kundali: kundali,
    mahadasha: mahadasha,
    antardasha: antardasha,
    date: date,
  );

  debugPrint('[HOROSCOPE][PROVIDER] SUCCESS');
  debugPrint('[HOROSCOPE][PROVIDER] CAREER=${result.career}');
  debugPrint('[HOROSCOPE][PROVIDER] FINANCE=${result.finance}');
  debugPrint('[HOROSCOPE][PROVIDER] RELATIONSHIPS=${result.relationships}');
  debugPrint('============================================================');

  return result;
});
