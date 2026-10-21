import 'package:flutter/foundation.dart';

import '../../../../core/config/app_initialization.dart';
import '../../../../core/storage/profile_storage.dart';
import '../../data/models/birth_profile_model.dart';

class BirthProfileRepository {
  final ProfileStorage _storage;

  BirthProfileRepository({ProfileStorage? storage})
    : _storage = storage ?? ProfileStorage();

  Future<List<BirthProfileModel>> getProfiles() async {
    final jsonProfiles = await _storage.loadProfiles();

    final profiles = <BirthProfileModel>[];

    for (final json in jsonProfiles) {
      try {
        profiles.add(BirthProfileModel.fromJson(json));
      } catch (error) {
        debugPrint('Invalid saved birth profile skipped: $error');
      }
    }

    return profiles;
  }

  Future<BirthProfileModel?> getProfile(String id) async {
    final profiles = await getProfiles();

    for (final profile in profiles) {
      if (profile.id == id) {
        return profile;
      }
    }

    return null;
  }

  Future<BirthProfileModel?> getActiveProfile() async {
    final profiles = await getProfiles();

    if (profiles.isEmpty) {
      return null;
    }

    final activeId = await _storage.getActiveProfileId();

    if (activeId != null) {
      for (final profile in profiles) {
        if (profile.id == activeId) {
          return profile;
        }
      }
    }

    // First profile becomes active automatically.
    await _storage.setActiveProfileId(profiles.first.id);

    return profiles.first;
  }

  Future<void> saveProfile(BirthProfileModel profile) async {
    final json = profile.toJson();

    // Always save locally first.
    await _storage.saveProfile(json);

    // Preserve current Supabase behavior.
    //
    // The local multi-profile system is authoritative for now.
    // Supabase schema migration should be done separately so that
    // existing production data is not accidentally broken.
    if (AppInitialization.supabaseAvailable) {
      try {
        final client = AppInitialization.supabase;
        final user = client.auth.currentUser;

        if (user != null) {
          // Do not send the new local-only metadata blindly until
          // the Supabase table schema has been migrated.
          final remoteJson = Map<String, dynamic>.from(json)
            ..remove('created_at')
            ..remove('updated_at')
            ..remove('relationship');

          await client.from('birth_profiles').upsert({
            'user_id': user.id,
            ...remoteJson,
          });
        }
      } catch (error) {
        debugPrint('Supabase profile save skipped: $error');
      }
    }
  }

  /// Removes every birth profile stored on this device. Cloud copies go
  /// with the account (see AuthService.deleteAccount).
  Future<void> clearLocalProfiles() => _storage.clearAll();

  Future<void> updateProfile(BirthProfileModel profile) async {
    await saveProfile(profile.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> deleteProfile(String id) async {
    await _storage.deleteProfile(id);

    if (AppInitialization.supabaseAvailable) {
      try {
        final client = AppInitialization.supabase;
        final user = client.auth.currentUser;

        if (user != null) {
          await client
              .from('birth_profiles')
              .delete()
              .eq('user_id', user.id)
              .eq('id', id);
        }
      } catch (error) {
        debugPrint('Supabase profile delete skipped: $error');
      }
    }
  }

  Future<void> setActiveProfile(String id) async {
    final profile = await getProfile(id);

    if (profile == null) {
      return;
    }

    await _storage.setActiveProfileId(id);
  }

  Future<void> clearAllProfiles() {
    return _storage.clearAll();
  }

  // Backward compatibility.
  Future<Map<String, dynamic>?> loadProfile() {
    return _storage.load();
  }

  Future<void> clearProfile() {
    return _storage.clear();
  }
}
