// lib/features/ai_astrologer/data/ai_consent.dart
//
// Remembers that the user agreed to send their question and chart summary to
// the AI providers (Groq, and Gemini as backup). Apple guideline 5.1.2(i)
// requires this explicit permission before personal data goes to a third-party AI.

import 'package:shared_preferences/shared_preferences.dart';

const _consentKey = 'ai_data_consent_v1';

Future<bool> hasAiConsent() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> saveAiConsent() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, true);
  } catch (_) {
    // Memory is best-effort: the user is asked again next time.
  }
}
