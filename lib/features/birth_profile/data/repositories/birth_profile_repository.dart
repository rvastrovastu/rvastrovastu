import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    // Cloud copies are kept only for email accounts. A guest session ends
    // when the app is removed, so a guest's cloud rows could never be
    // reached again; guests keep their profiles on the phone.
    if (AppInitialization.supabaseAvailable) {
      try {
        final client = AppInitialization.supabase;
        final user = client.auth.currentUser;

        if (user != null && !user.isAnonymous) {
          await _upload(client, user.id, json);
        }
      } catch (error) {
        debugPrint('Supabase profile save skipped: $error');
      }
    }
  }

  /// Brings the signed-in account's birth profiles onto this device, and
  /// uploads profiles saved here that the account doesn't have yet. When both
  /// copies exist, the one updated most recently is kept.
  Future<void> syncWithAccount() async {
    if (!AppInitialization.supabaseAvailable) return;
    final client = AppInitialization.supabase;
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final rows = await client.from('birth_profiles').select().eq('user_id', user.id);

      final cloud = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final json = Map<String, dynamic>.from(row)..remove('user_id');
        final id = json['id'] as String?;
        if (id != null && id.isNotEmpty) cloud[id] = json;
      }

      final local = <String, Map<String, dynamic>>{};
      for (final json in await _storage.loadProfiles()) {
        final id = json['id'] as String?;
        if (id != null && id.isNotEmpty) local[id] = json;
      }

      final merged = <String, Map<String, dynamic>>{...cloud};
      for (final entry in local.entries) {
        final remote = cloud[entry.key];
        if (remote == null) {
          merged[entry.key] = entry.value;
          await _upload(client, user.id, entry.value);
        } else if (_isNewer(entry.value, remote)) {
          // Keep local-only fields (created_at) the cloud copy lacks.
          merged[entry.key] = {
            ...remote,
            ...entry.value,
          };
          await _upload(client, user.id, entry.value);
        }
      }

      await _storage.saveProfiles(merged.values.toList());
    } catch (error) {
      debugPrint('Birth profile sync skipped: $error');
    }
  }

  Future<void> _upload(
    SupabaseClient client,
    String userId,
    Map<String, dynamic> json,
  ) async {
    // updated_at goes up as UTC so the newest copy wins on every phone;
    // the database keeps its own created_at.
    final remote = Map<String, dynamic>.from(json)..remove('created_at');
    final updated = DateTime.tryParse(json['updated_at'] as String? ?? '');
    remote['updated_at'] = (updated ?? DateTime.now()).toUtc().toIso8601String();
    await client.from('birth_profiles').upsert({'user_id': userId, ...remote});
  }

  bool _isNewer(Map<String, dynamic> local, Map<String, dynamic> remote) {
    final localUpdated = DateTime.tryParse(local['updated_at'] as String? ?? '');
    final remoteUpdated = DateTime.tryParse(remote['updated_at'] as String? ?? '');
    if (remoteUpdated == null) return true;
    if (localUpdated == null) return false;
    return localUpdated.isAfter(remoteUpdated);
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
