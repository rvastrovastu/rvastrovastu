import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProfileStorage {
  static const String _profileKey = 'birth_profile';

  Future<void> save(Map<String, dynamic> profile) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_profileKey, jsonEncode(profile));
  }

  Future<Map<String, dynamic>?> load() async {
    final preferences = await SharedPreferences.getInstance();

    final value = preferences.getString(_profileKey);

    if (value == null || value.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(value);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return null;
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_profileKey);
  }
}
