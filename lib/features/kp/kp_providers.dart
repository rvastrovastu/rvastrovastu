import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../panchang/presentation/providers/panchang_location_provider.dart';
import 'kp.dart';
import 'kp_repository.dart';

final kpRepositoryProvider = Provider<KpRepository>((ref) => KpRepository());

/// The active profile's birth chart in KP.
final natalKpProvider = FutureProvider<KpChart?>((ref) async {
  final profile = ref.watch(birthProfileProvider);
  if (profile == null) return null;
  final zone = profile.location.timezone;
  return ref
      .watch(kpRepositoryProvider)
      .cast(
        utc: birthMomentUtc(profile.dateOfBirth, profile.birthTime, zone),
        latitude: profile.location.latitude,
        longitude: profile.location.longitude,
        timezone: zone,
      );
});

/// A horary (Prashna) chart cast on request for this moment and place.
class PrashnaNotifier extends Notifier<AsyncValue<KpChart?>> {
  @override
  AsyncValue<KpChart?> build() => const AsyncData(null);

  Future<void> cast() async {
    final place = ref.read(panchangPlaceProvider).value;
    if (place == null) {
      state = AsyncError(StateError('no place'), StackTrace.current);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(kpRepositoryProvider)
          .cast(
            utc: DateTime.now().toUtc(),
            latitude: place.location.latitude,
            longitude: place.location.longitude,
            timezone: place.location.timezone,
          ),
    );
  }
}

final prashnaProvider = NotifierProvider<PrashnaNotifier, AsyncValue<KpChart?>>(
  PrashnaNotifier.new,
);
