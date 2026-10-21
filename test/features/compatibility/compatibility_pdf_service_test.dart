import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/kundali.dart';
import 'package:rv_astro_vastu/features/compatibility/data/services/compatibility_pdf_service.dart';
import 'package:rv_astro_vastu/features/compatibility/domain/entities/compatibility_result.dart';
import 'package:rv_astro_vastu/features/compatibility/domain/entities/koota_score.dart';
import 'package:rv_astro_vastu/features/dosha/domain/usecases/check_manglik_dosha.dart';

import '../dosha/dosha_test_helpers.dart';

CompatibilityResult _result({List<String> flags = const []}) =>
    CompatibilityResult(
      kootas: const [
        KootaScore(name: 'Varna', score: 1, maximum: 1, explanation: 'Varna.'),
        KootaScore(
          name: 'Vashya',
          score: 0.5,
          maximum: 2,
          explanation: 'Vashya.',
        ),
        KootaScore(name: 'Tara', score: 3, maximum: 3, explanation: 'Tara.'),
        KootaScore(name: 'Yoni', score: 2, maximum: 4, explanation: 'Yoni.'),
        KootaScore(
          name: 'Graha Maitri',
          score: 5,
          maximum: 5,
          explanation: 'Graha Maitri.',
        ),
        KootaScore(name: 'Gana', score: 6, maximum: 6, explanation: 'Gana.'),
        KootaScore(
          name: 'Bhakoot',
          score: 0,
          maximum: 7,
          explanation: 'Bhakoot.',
        ),
        KootaScore(name: 'Nadi', score: 0, maximum: 8, explanation: 'Nadi.'),
      ],
      traditionalFlags: flags,
    );

Kundali _chart(String moonSign) => kundaliFrom(
  ascendant: inSign('Leo', 1),
  longitudes: {
    'Rahu': inSign('Aries', 2),
    'Sun': inSign('Taurus'),
    'Moon': inSign(moonSign, 1),
    'Mars': inSign('Gemini'),
    'Mercury': inSign('Taurus', 20),
    'Jupiter': inSign('Cancer'),
    'Venus': inSign('Gemini', 25),
    'Saturn': inSign('Virgo'),
  },
);

CompatibilityReportPerson _person(String name, String moonSign) {
  final kundali = _chart(moonSign);
  return CompatibilityReportPerson(
    name: name,
    dateOfBirth: DateTime(1992, 3, 4),
    birthTime: '06:30',
    place: 'Pune, India',
    kundali: kundali,
    manglik: const CheckManglikDosha()(kundali),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('helpers', () {
    test('score bands follow the traditional thresholds', () {
      expect(CompatibilityBand.of(36), CompatibilityBand.excellent);
      expect(CompatibilityBand.of(28), CompatibilityBand.excellent);
      expect(CompatibilityBand.of(27.5), CompatibilityBand.good);
      expect(CompatibilityBand.of(24), CompatibilityBand.good);
      expect(CompatibilityBand.of(23.5), CompatibilityBand.average);
      expect(CompatibilityBand.of(18), CompatibilityBand.average);
      expect(CompatibilityBand.of(17.5), CompatibilityBand.low);
    });

    test('koota level and keys', () {
      final kootas = _result().kootas;
      expect(kootaLevel(kootas[0]), 'full');
      expect(kootaLevel(kootas[1]), 'partial');
      expect(kootaLevel(kootas[6]), 'none');
      expect(kootaKey('Graha Maitri'), 'grahaMaitri');
      expect(kootaKey('Nadi'), 'nadi');
    });

    test('flag keys', () {
      expect(
        flagKey('Traditional Nadi dosha flag: both share a Nadi.'),
        'nadi',
      );
      expect(flagKey('Traditional Bhakoot dosha flag: 6/8.'), 'bhakoot');
      expect(flagKey('Something else'), isNull);
    });
  });

  for (final language in CompatibilityReportLanguage.values) {
    test('builds a full ${language.name} report', () async {
      final bytes = await const CompatibilityPdfService().buildReport(
        bride: _person('Asha', 'Aquarius'),
        groom: _person('Ravi', 'Cancer'),
        result: _result(
          flags: const [
            'Traditional Nadi dosha flag: both nakshatras share a Nadi.',
            'Traditional Bhakoot dosha flag: 6/8.',
          ],
        ),
        reportDate: DateTime(2026, 10, 20),
        language: language,
      );

      expect(bytes.length, greaterThan(5000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  }

  test('works from scores alone', () async {
    final bytes = await const CompatibilityPdfService().buildReport(
      bride: const CompatibilityReportPerson(name: 'Bride'),
      groom: const CompatibilityReportPerson(name: 'Groom'),
      result: _result(),
      reportDate: DateTime(2026, 10, 20),
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
