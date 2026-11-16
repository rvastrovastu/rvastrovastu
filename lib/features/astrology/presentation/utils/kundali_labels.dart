// lib/features/astrology/presentation/utils/kundali_labels.dart
//
// Translated labels for the kundali details card. Falls back to English.

import 'package:flutter/widgets.dart';

abstract final class KundaliLabels {
  static String of(BuildContext context, String key) {
    final lang = Localizations.localeOf(context).languageCode;
    return _table[lang]?[key] ?? _table['en']![key] ?? key;
  }

  static const Map<String, Map<String, String>> _table = {
    'en': {
      'birthTime': 'Birth Time',
      'birthPlace': 'Birth Place',
      'coordinates': 'Coordinates',
      'timezone': 'Timezone',
    },
    'hi': {
      'birthTime': 'जन्म समय',
      'birthPlace': 'जन्म स्थान',
      'coordinates': 'निर्देशांक',
      'timezone': 'समय क्षेत्र',
    },
    'gu': {
      'birthTime': 'જન્મ સમય',
      'birthPlace': 'જન્મ સ્થળ',
      'coordinates': 'કોઓર્ડિનેટ્સ',
      'timezone': 'સમય ક્ષેત્ર',
    },
    'mr': {
      'birthTime': 'जन्मवेळ',
      'birthPlace': 'जन्मस्थान',
      'coordinates': 'निर्देशांक',
      'timezone': 'वेळ क्षेत्र',
    },
    'bn': {
      'birthTime': 'জন্মের সময়',
      'birthPlace': 'জন্মস্থান',
      'coordinates': 'স্থানাঙ্ক',
      'timezone': 'সময় অঞ্চল',
    },
    'ta': {
      'birthTime': 'பிறந்த நேரம்',
      'birthPlace': 'பிறந்த இடம்',
      'coordinates': 'ஆயத்தொலைவுகள்',
      'timezone': 'நேர மண்டலம்',
    },
    'te': {
      'birthTime': 'పుట్టిన సమయం',
      'birthPlace': 'పుట్టిన ప్రదేశం',
      'coordinates': 'అక్షాంశ రేఖాంశాలు',
      'timezone': 'కాల మండలం',
    },
    'kn': {
      'birthTime': 'ಜನ್ಮ ಸಮಯ',
      'birthPlace': 'ಜನ್ಮ ಸ್ಥಳ',
      'coordinates': 'ನಿರ್ದೇಶಾಂಕಗಳು',
      'timezone': 'ಸಮಯ ವಲಯ',
    },
    'ml': {
      'birthTime': 'ജനന സമയം',
      'birthPlace': 'ജനന സ്ഥലം',
      'coordinates': 'കോർഡിനേറ്റുകൾ',
      'timezone': 'സമയ മേഖല',
    },
    'pa': {
      'birthTime': 'ਜਨਮ ਸਮਾਂ',
      'birthPlace': 'ਜਨਮ ਸਥਾਨ',
      'coordinates': 'ਨਿਰਦੇਸ਼ਾਂਕ',
      'timezone': 'ਸਮਾਂ ਖੇਤਰ',
    },
    'es': {
      'birthTime': 'Hora de nacimiento',
      'birthPlace': 'Lugar de nacimiento',
      'coordinates': 'Coordenadas',
      'timezone': 'Zona horaria',
    },
  };
}
