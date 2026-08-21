import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/birth_profile_model.dart';
import '../../data/repositories/birth_profile_repository.dart';
import '../../domain/entities/birth_location.dart';

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
      final dateOfBirth = DateTime.parse(json['date_of_birth'] as String);

      final location = BirthLocation(
        city: json['birth_city'] as String? ?? '',
        state: json['birth_state'] as String? ?? '',
        country: json['birth_country'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        timezone: json['timezone'] as String? ?? 'UTC',
      );

      state = BirthProfileModel(
        name: json['name'] as String? ?? '',
        gender: json['gender'] as String? ?? '',
        dateOfBirth: dateOfBirth,
        birthTime: json['birth_time'] as String? ?? '',
        location: location,
      );
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
