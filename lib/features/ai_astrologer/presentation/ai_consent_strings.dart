// lib/features/ai_astrologer/presentation/ai_consent_strings.dart
//
// Text for the AI data-sharing consent dialog. Falls back to English.

import 'package:flutter/widgets.dart';

abstract final class AiConsentStr {
  static String of(BuildContext context, String key) {
    final lang = Localizations.localeOf(context).languageCode;
    return _table[lang]?[key] ?? _table['en']![key] ?? key;
  }

  static const Map<String, Map<String, String>> _table = {
    'en': {
      'title': 'Share with AI astrologer?',
      'body':
          'To answer, Ask AI sends your question, a summary of your birth chart '
              'and recent messages in this chat to our AI providers: Groq, and '
              'Google Gemini as a backup. They use it only to write the reply. '
              'Your birth details are not sent to anyone else.',
      'yes': 'I agree',
      'no': 'Not now',
    },
    'hi': {
      'title': 'AI ज्योतिषी के साथ साझा करें?',
      'body':
          'उत्तर देने के लिए, Ask AI आपका प्रश्न, आपकी जन्म कुंडली का सारांश और '
              'इस चैट के हाल के संदेश हमारे AI प्रदाताओं को भेजता है: Groq, और '
              'बैकअप के रूप में Google Gemini। वे इसका उपयोग केवल उत्तर लिखने के लिए करते हैं।',
      'yes': 'मैं सहमत हूँ',
      'no': 'अभी नहीं',
    },
    'gu': {
      'title': 'AI જ્યોતિષી સાથે શેર કરીએ?',
      'body':
          'જવાબ આપવા માટે, Ask AI તમારો પ્રશ્ન, તમારી જન્મ કુંડળીનો સારાંશ અને આ ચેટના '
              'તાજેતરના સંદેશા અમારા AI પ્રદાતાઓને મોકલે છે: Groq, અને બેકઅપ તરીકે Google Gemini. '
              'તેઓ તેનો ઉપયોગ ફક્ત જવાબ લખવા માટે કરે છે.',
      'yes': 'હું સંમત છું',
      'no': 'હમણાં નહીં',
    },
    'es': {
      'title': '¿Compartir con el astrólogo IA?',
      'body':
          'Para responder, Ask AI envía tu pregunta, un resumen de tu carta natal y '
              'los mensajes recientes de este chat a nuestros proveedores de IA: Groq, '
              'y Google Gemini como respaldo. Solo los usan para escribir la respuesta.',
      'yes': 'Acepto',
      'no': 'Ahora no',
    },
  };
}
