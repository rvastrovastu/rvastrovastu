import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/birth_profile_model.dart';
import '../../data/repositories/birth_profile_repository.dart';

final birthProfileRepositoryProvider = Provider<BirthProfileRepository>((ref) {
  return BirthProfileRepository();
});

final birthProfileProvider =
    NotifierProvider<BirthProfileNotifier, BirthProfileModel?>(
      BirthProfileNotifier.new,
    );

class BirthProfileNotifier extends Notifier<BirthProfileModel?> {
  @override
  BirthProfileModel? build() {
    _loadSavedProfile();
    return null;
  }

  Future<void> _loadSavedProfile() async {
    final repository = ref.read(birthProfileRepositoryProvider);
    final json = await repository.loadProfile();

    if (json == null) {
      return;
    }

    try {
      state = BirthProfileModel.fromJson(json);
    } catch (error) {
      // Invalid persisted profile should not prevent the app from starting.
      state = null;
    }
  }

  Future<void> saveProfile(BirthProfileModel profile) async {
    final repository = ref.read(birthProfileRepositoryProvider);

    await repository.saveProfile(profile);

    state = profile;
  }

  Future<void> loadProfile() async {
    await _loadSavedProfile();
  }

  void clearProfile() {
    state = null;
  }
}
