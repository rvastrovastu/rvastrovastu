import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/birth_profile_model.dart';
import '../../data/repositories/birth_profile_repository.dart';

final birthProfileRepositoryProvider = Provider<BirthProfileRepository>((ref) {
  return BirthProfileRepository();
});

/// All saved birth profiles.
final birthProfilesProvider =
    NotifierProvider<BirthProfilesNotifier, List<BirthProfileModel>>(
      BirthProfilesNotifier.new,
    );

/// The currently active birth profile.
///
/// This is the profile used for:
/// - Kundali
/// - Rashi
/// - Nakshatra
/// - Dasha
/// - personalized astrology
final birthProfileProvider =
    NotifierProvider<BirthProfileNotifier, BirthProfileModel?>(
      BirthProfileNotifier.new,
    );

class BirthProfilesNotifier extends Notifier<List<BirthProfileModel>> {
  @override
  List<BirthProfileModel> build() {
    _loadProfiles();
    return const [];
  }

  Future<void> _loadProfiles() async {
    final repository = ref.read(birthProfileRepositoryProvider);
    final profiles = await repository.getProfiles();

    if (!ref.mounted) return;

    state = profiles;
  }

  Future<void> reload() async {
    await _loadProfiles();
  }

  Future<void> saveProfile(
    BirthProfileModel profile, {
    bool makeActive = true,
  }) async {
    final repository = ref.read(birthProfileRepositoryProvider);

    await repository.saveProfile(profile);

    if (makeActive) {
      await repository.setActiveProfile(profile.id);

      if (ref.mounted) {
        await ref.read(birthProfileProvider.notifier).loadProfile();
      }
    }

    if (ref.mounted) {
      await _loadProfiles();
    }
  }

  Future<void> updateProfile(BirthProfileModel profile) async {
    final repository = ref.read(birthProfileRepositoryProvider);

    await repository.updateProfile(profile);

    if (!ref.mounted) return;

    await ref.read(birthProfileProvider.notifier).loadProfile();
    await _loadProfiles();
  }

  Future<void> setActiveProfile(String id) async {
    final repository = ref.read(birthProfileRepositoryProvider);

    final profile = await repository.getProfile(id);

    if (profile == null) return;

    await repository.setActiveProfile(id);

    if (!ref.mounted) return;

    // CRITICAL:
    // Synchronize the compatibility/active provider immediately.
    await ref.read(birthProfileProvider.notifier).loadProfile();

    await _loadProfiles();
  }

  Future<void> deleteProfile(String id) async {
    final repository = ref.read(birthProfileRepositoryProvider);

    await repository.deleteProfile(id);

    if (!ref.mounted) return;

    await ref.read(birthProfileProvider.notifier).loadProfile();
    await _loadProfiles();
  }
}

class BirthProfileNotifier extends Notifier<BirthProfileModel?> {
  @override
  BirthProfileModel? build() {
    _loadSavedProfile();
    return null;
  }

  Future<void> _loadSavedProfile() async {
    final repository = ref.read(birthProfileRepositoryProvider);

    final profile = await repository.getActiveProfile();

    if (!ref.mounted) return;

    state = profile;
  }

  Future<void> loadProfile() async {
    await _loadSavedProfile();
  }

  Future<void> saveProfile(BirthProfileModel profile) async {
    final repository = ref.read(birthProfileRepositoryProvider);

    await repository.saveProfile(profile);
    await repository.setActiveProfile(profile.id);

    if (!ref.mounted) return;

    state = profile;

    ref.invalidate(birthProfilesProvider);
  }

  Future<void> selectProfile(BirthProfileModel profile) async {
    final repository = ref.read(birthProfileRepositoryProvider);

    await repository.setActiveProfile(profile.id);

    if (!ref.mounted) return;

    state = profile;

    ref.invalidate(birthProfilesProvider);
  }

  Future<void> updateProfile(BirthProfileModel profile) async {
    final repository = ref.read(birthProfileRepositoryProvider);

    await repository.updateProfile(profile);

    if (!ref.mounted) return;

    state = profile;

    ref.invalidate(birthProfilesProvider);
  }

  Future<void> clearProfile() async {
    final repository = ref.read(birthProfileRepositoryProvider);

    final current = state;

    if (current != null) {
      await repository.deleteProfile(current.id);
    }

    if (!ref.mounted) return;

    state = await repository.getActiveProfile();

    ref.invalidate(birthProfilesProvider);
  }
}
