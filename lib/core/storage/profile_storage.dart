import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProfileStorage {
  static const String _legacyProfileKey = 'birth_profile';

  static const String _profilesKey = 'birth_profiles';
  static const String _activeProfileIdKey = 'active_birth_profile_id';

  Future<void> saveProfiles(List<Map<String, dynamic>> profiles) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_profilesKey, jsonEncode(profiles));
  }

  Future<List<Map<String, dynamic>>> loadProfiles() async {
    final preferences = await SharedPreferences.getInstance();

    final value = preferences.getString(_profilesKey);

    if (value != null && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);

        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (_) {
        // Fall through to legacy migration.
      }
    }

    // Automatic migration from the previous single-profile storage.
    final legacyValue = preferences.getString(_legacyProfileKey);

    if (legacyValue == null || legacyValue.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(legacyValue);

      if (decoded is Map) {
        final migratedProfile = Map<String, dynamic>.from(decoded);

        if ((migratedProfile['id'] as String?)?.isNotEmpty != true) {
          migratedProfile['id'] = DateTime.now().microsecondsSinceEpoch
              .toString();
        }

        migratedProfile['relationship'] ??= 'Self';

        final now = DateTime.now().toIso8601String();

        migratedProfile['created_at'] ??= now;
        migratedProfile['updated_at'] ??= now;

        final profiles = [migratedProfile];

        await saveProfiles(profiles);

        await setActiveProfileId(migratedProfile['id'] as String);

        return profiles;
      }
    } catch (_) {
      return [];
    }

    return [];
  }

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    final profiles = await loadProfiles();

    final id = profile['id'] as String?;

    final index = profiles.indexWhere((item) => item['id'] == id);

    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }

    await saveProfiles(profiles);
  }

  Future<void> deleteProfile(String id) async {
    final profiles = await loadProfiles();

    profiles.removeWhere((profile) => profile['id'] == id);

    await saveProfiles(profiles);

    final activeId = await getActiveProfileId();

    if (activeId == id) {
      if (profiles.isEmpty) {
        await clearActiveProfileId();
      } else {
        await setActiveProfileId(profiles.first['id'] as String);
      }
    }
  }

  Future<String?> getActiveProfileId() async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getString(_activeProfileIdKey);
  }

  Future<void> setActiveProfileId(String id) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_activeProfileIdKey, id);
  }

  Future<void> clearActiveProfileId() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_activeProfileIdKey);
  }

  Future<void> clearAll() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_profilesKey);
    await preferences.remove(_activeProfileIdKey);
    await preferences.remove(_legacyProfileKey);
  }

  // Backward-compatible API.
  //
  // Existing code may still call load(), save(), and clear().
  Future<void> save(Map<String, dynamic> profile) {
    return saveProfile(profile);
  }

  Future<Map<String, dynamic>?> load() async {
    final profiles = await loadProfiles();

    if (profiles.isEmpty) {
      return null;
    }

    final activeId = await getActiveProfileId();

    if (activeId != null) {
      for (final profile in profiles) {
        if (profile['id'] == activeId) {
          return profile;
        }
      }
    }

    return profiles.first;
  }

  Future<void> clear() {
    return clearAll();
  }
}
