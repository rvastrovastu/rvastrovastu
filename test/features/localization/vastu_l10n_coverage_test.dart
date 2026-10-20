import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const requiredVastuKeys = <String>[
    'vastuEntranceAnalysis',
    'vastuSelectEntrance',
    'vastuEntrancePada',
    'vastuAssessment',
    'vastuFavorable',
    'vastuTraditionalAssessment',
    'vastuW4',
    'vastuW5',
    'vastuPushpadanta',
    'vastuVaruna',
    'vastuW4Summary',
    'vastuW5Summary',
    'vastuNoSupportedEntrySegments',
    'vastuNeutral',
    'vastuChallenging',
    'vastuEntranceDirection',
    'vastuEntrancePosition',
    'vastuPositionStart',
    'vastuPositionEnd',
    'vastuCalculatedPada',
    'vastuAssessmentUnavailable',
    'vastuSelectDirection',
    'vastuNorth',
    'vastuEast',
    'vastuSouth',
    'vastuWest',
  ];

  const locales = <String>[
    'bn',
    'en',
    'es',
    'gu',
    'hi',
    'kn',
    'ml',
    'mr',
    'pa',
    'ta',
    'te',
  ];

  test('all supported locales contain the complete Vastu key set', () {
    final missing = <String, List<String>>{};

    for (final locale in locales) {
      final file = File('lib/l10n/app_$locale.arb');

      expect(
        file.existsSync(),
        isTrue,
        reason: 'Missing ARB file for locale: $locale',
      );

      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final missingKeys = requiredVastuKeys
          .where((key) => !data.containsKey(key))
          .toList();

      if (missingKeys.isNotEmpty) {
        missing[locale] = missingKeys;
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'Missing Vastu localization keys: $missing',
    );
  });
}
