import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(
  LanguageNotifier.new,
);

class LanguageNotifier extends Notifier<AppLanguage> {
  static const String _key = 'app_language';

  @override
  AppLanguage build() {
    _loadSavedLanguage();
    return AppLanguage.english;
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_key);

    if (savedCode != null && savedCode.isNotEmpty) {
      state = AppLanguage.fromCode(savedCode);
    }
  }

  Future<bool> hasSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_key);

    return savedCode != null && savedCode.isNotEmpty;
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.code);
  }

  Future<void> clearLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);

    state = AppLanguage.english;
  }
}
