import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/festivals/domain/entities/calendar_observance.dart';
import 'package:rv_astro_vastu/features/festivals/guide/data/puja_guide_repository.dart';
import 'package:rv_astro_vastu/features/festivals/guide/domain/puja_guide_spec.dart';

import 'puja_guide_test_bundle.dart';

void main() {
  final repository = PujaGuideRepository(FileAssetBundle());

  test('every observance has a spec', () {
    expect(pujaGuideSpecs.keys.toSet(), ObservanceId.values.toSet());
  });

  test('every aarti in the specs exists, with matching lines', () async {
    final aartis = await repository.aartis();
    for (final spec in pujaGuideSpecs.values) {
      for (final key in spec.aartis) {
        expect(aartis, contains(key));
      }
    }
    for (final aarti in aartis.values) {
      expect(aarti.devanagari.length, aarti.latin.length, reason: aarti.key);
      expect(aarti.devanagari.where((l) => l.isNotEmpty), isNotEmpty);
    }
  });

  for (final lang in PujaGuideRepository.languages) {
    test('$lang guides cover every observance', () async {
      final guides = await repository.guides(lang);
      expect(guides.keys.toSet(), ObservanceId.values.toSet());
      for (final MapEntry(key: id, value: guide) in guides.entries) {
        expect(
          guide.mantraMeanings.length,
          pujaGuideSpecs[id]!.mantras.length,
          reason: '$lang ${id.name}',
        );
        expect(guide.steps.length, greaterThanOrEqualTo(3));
        expect(guide.samagri, isNotEmpty);
      }
    });
  }

  test('other languages fall back to English', () {
    expect(PujaGuideRepository.guideLanguage('ta'), 'en');
    expect(PujaGuideRepository.guideLanguage('hi'), 'hi');
  });
}
