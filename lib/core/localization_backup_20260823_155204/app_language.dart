import 'package:flutter/material.dart';

enum AppLanguage {
  english(code: 'en', name: 'English', nativeName: 'English'),
  hindi(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
  spanish(code: 'es', name: 'Spanish', nativeName: 'Español'),
  gujarati(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી'),
  marathi(code: 'mr', name: 'Marathi', nativeName: 'मराठी'),
  bengali(code: 'bn', name: 'Bengali', nativeName: 'বাংলা'),
  tamil(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
  telugu(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
  kannada(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
  malayalam(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം'),
  punjabi(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ');

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  final String code;
  final String name;
  final String nativeName;

  // English display name used by the language selector.
  String get englishName => name;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (language) => language.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}
