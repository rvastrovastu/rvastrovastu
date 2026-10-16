import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/astrology_repository.dart';
import '../../data/repositories/swiss_ephemeris_astrology_repository.dart';
import '../../domain/entities/kundali.dart';
import '../../domain/models/kundali_input.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';

final astrologyRepositoryProvider = Provider<AstrologyRepository>((ref) {
  return SwissEphemerisAstrologyRepository();
});

final kundaliProvider = FutureProvider<Kundali?>((ref) async {
  debugPrint('============================================================');
  debugPrint('[KUNDALI][PROVIDER] CALLED');

  final profile = ref.watch(birthProfileProvider);

  if (profile == null) {
    debugPrint('[KUNDALI][PROVIDER] NO ACTIVE PROFILE');
    debugPrint('============================================================');
    return null;
  }

  debugPrint('[KUNDALI][PROVIDER] PROFILE=${profile.name}');
  debugPrint('[KUNDALI][PROVIDER] DOB=${profile.dateOfBirth}');
  debugPrint('[KUNDALI][PROVIDER] BIRTH TIME=${profile.birthTime}');
  debugPrint(
    '[KUNDALI][PROVIDER] LOCATION='
    '${profile.location.latitude},'
    '${profile.location.longitude}',
  );
  debugPrint('[KUNDALI][PROVIDER] TIMEZONE=${profile.location.timezone}');

  final repository = ref.watch(astrologyRepositoryProvider);

  final input = KundaliInput(
    dateOfBirth: profile.dateOfBirth,
    birthTime: profile.birthTime,
    latitude: profile.location.latitude,
    longitude: profile.location.longitude,
    timezone: profile.location.timezone,
  );

  debugPrint('[KUNDALI][PROVIDER] CALLING SWISS EPHEMERIS');

  try {
    final result = await repository.calculateKundali(input);

    debugPrint('[KUNDALI][PROVIDER] SUCCESS');
    debugPrint('[KUNDALI][PROVIDER] ASC=${result.ascendant}');
    debugPrint('[KUNDALI][PROVIDER] ASC DEG=${result.ascendantDegree}');
    debugPrint('[KUNDALI][PROVIDER] MOON SIGN=${result.moonSign}');
    debugPrint('[KUNDALI][PROVIDER] MOON LONGITUDE=${result.moonLongitude}');
    debugPrint('[KUNDALI][PROVIDER] NAKSHATRA=${result.nakshatra}');
    debugPrint('[KUNDALI][PROVIDER] PADA=${result.nakshatraPada}');
    debugPrint('============================================================');

    return result;
  } catch (error, stack) {
    debugPrint('[KUNDALI][PROVIDER] ERROR=$error');
    debugPrint('$stack');
    debugPrint('============================================================');
    rethrow;
  }
});
