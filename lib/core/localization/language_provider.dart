import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(
  LanguageNotifier.new,
);

class LanguageNotifier extends Notifier<AppLanguage> {
  static const String _key = 'app_language';

  bool _hasSavedLanguage = false;

  bool get hasSavedLanguage => _hasSavedLanguage;

  @override
  AppLanguage build() {
    _loadSavedLanguage();
    return AppLanguage.english;
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_key);

    if (savedCode != null && savedCode.isNotEmpty) {
      _hasSavedLanguage = true;
      state = AppLanguage.fromCode(savedCode);
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    _hasSavedLanguage = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.code);
  }

  Future<bool> hasSavedLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_key);

    _hasSavedLanguage = savedCode != null && savedCode.isNotEmpty;

    return _hasSavedLanguage;
  }
}
