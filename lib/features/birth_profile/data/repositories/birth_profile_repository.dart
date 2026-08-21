import 'package:flutter/foundation.dart';

import '../../../../core/config/app_initialization.dart';
import '../../../../core/storage/profile_storage.dart';
import '../../data/models/birth_profile_model.dart';

class BirthProfileRepository {
  final ProfileStorage _storage;

  BirthProfileRepository({ProfileStorage? storage})
    : _storage = storage ?? ProfileStorage();

  Future<void> saveProfile(BirthProfileModel profile) async {
    final json = profile.toJson();

    // Always save locally first.
    await _storage.save(json);

    // Save to Supabase when configured and authenticated.
    if (AppInitialization.supabaseAvailable) {
      try {
        final client = AppInitialization.supabase;

        final user = client.auth.currentUser;

        if (user != null) {
          await client.from('birth_profiles').upsert({
            'user_id': user.id,
            ...json,
          });
        }
      } catch (error) {
        // Local persistence remains successful even if
        // Supabase isn't configured or temporarily unavailable.
        debugPrint('Supabase profile save skipped: $error');
      }
    }
  }

  Future<Map<String, dynamic>?> loadProfile() {
    return _storage.load();
  }

  Future<void> clearProfile() {
    return _storage.clear();
  }
}
