import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../astrology/domain/models/kundali_input.dart';
import '../astrology/presentation/providers/astrology_provider.dart';
import '../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../dosha/domain/entities/zodiac_signs.dart';
import 'solar_return.dart';
import 'varshphal.dart';

final solarReturnFinderProvider = Provider<SolarReturnFinder>(
  (ref) => SwissSolarReturnFinder(),
);

/// Years completed today by the active profile, or null with no profile.
final currentVarshaProvider = Provider<int?>((ref) {
  final profile = ref.watch(birthProfileProvider);
  if (profile == null) return null;
  return completedYearsOn(profile.dateOfBirth, DateTime.now());
});

/// The annual chart that starts after [completedYears] years of life.
final varshphalProvider = FutureProvider.family<Varshphal?, int>((
  ref,
  completedYears,
) async {
  final profile = ref.watch(birthProfileProvider);
  if (profile == null) return null;
  final natal = await ref.watch(kundaliProvider.future);
  if (natal == null) return null;

  final sun = natal.planets.firstWhere((p) => p.planet == 'Sun').longitude;
  final dob = profile.dateOfBirth;
  final utc = await ref
      .watch(solarReturnFinderProvider)
      .find(
        sun,
        DateTime.utc(dob.year + completedYears, dob.month, dob.day, 12),
      );

  final zone = profile.location.timezone.trim();
  final local = tz.TZDateTime.from(utc, tz.getLocation(zone));
  String two(int v) => v.toString().padLeft(2, '0');
  final chart = await ref
      .watch(astrologyRepositoryProvider)
      .calculateKundali(
        KundaliInput(
          dateOfBirth: DateTime(local.year, local.month, local.day),
          birthTime:
              '${two(local.hour)}:${two(local.minute)}:${two(local.second)}',
          latitude: profile.location.latitude,
          longitude: profile.location.longitude,
          timezone: zone,
        ),
      );

  return Varshphal(
    completedYears: completedYears,
    praveshUtc: utc,
    praveshLocal: DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    ),
    chart: chart,
    natalLagna: zodiacSignIndex(natal.ascendant),
  );
});
