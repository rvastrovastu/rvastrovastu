import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';

import '../../data/repositories/astrology_repository.dart';
import '../../data/repositories/swiss_ephemeris_astrology_repository.dart';

import '../../domain/entities/kundali.dart';
import '../../domain/models/kundali_input.dart';

final astrologyRepositoryProvider = Provider<AstrologyRepository>((ref) {
  return SwissEphemerisAstrologyRepository();
});

final kundaliProvider = FutureProvider<Kundali?>((ref) async {
  final profile = ref.watch(birthProfileProvider);

  if (profile == null) {
    return null;
  }

  final repository = ref.watch(astrologyRepositoryProvider);

  final input = KundaliInput(
    dateOfBirth: profile.dateOfBirth,
    birthTime: profile.birthTime,
    latitude: profile.location.latitude,
    longitude: profile.location.longitude,
    timezone: profile.location.timezone,
  );

  return repository.calculateKundali(input);
});
