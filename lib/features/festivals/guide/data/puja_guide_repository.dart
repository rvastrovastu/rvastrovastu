import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/calendar_observance.dart';
import '../domain/puja_guide.dart';

/// Reads the bundled puja guides and aartis.
class PujaGuideRepository {
  /// Languages with their own guide text; others fall back to English.
  static const languages = {'en', 'hi', 'mr'};

  final AssetBundle bundle;

  PujaGuideRepository([AssetBundle? bundle]) : bundle = bundle ?? rootBundle;

  /// The guide language used for [languageCode].
  static String guideLanguage(String languageCode) =>
      languages.contains(languageCode) ? languageCode : 'en';

  Future<Map<ObservanceId, PujaGuide>> guides(String languageCode) async {
    final lang = guideLanguage(languageCode);
    final json = await _json('assets/puja_guides/$lang.json');
    return {
      for (final id in ObservanceId.values)
        if (json[id.name] case final Map<String, dynamic> entry)
          id: PujaGuide.fromJson(id, entry),
    };
  }

  Future<Map<String, Aarti>> aartis() async {
    final json = await _json('assets/puja_guides/aartis.json');
    return {
      for (final MapEntry(:key, :value) in json.entries)
        key: Aarti.fromJson(key, value as Map<String, dynamic>),
    };
  }

  // Decoded here rather than with loadString, which hands large files to
  // an isolate.
  Future<Map<String, dynamic>> _json(String path) async {
    final data = await bundle.load(path);
    final text = utf8.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    return jsonDecode(text) as Map<String, dynamic>;
  }
}
