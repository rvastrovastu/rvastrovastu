import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/compatibility/data/services/compatibility_pdf_service.dart';
import 'package:rv_astro_vastu/features/compatibility/domain/entities/compatibility_result.dart';
import 'package:rv_astro_vastu/features/compatibility/domain/entities/koota_score.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CompatibilityPdfService', () {
    test('generates a non-empty PDF with the expected PDF signature', () async {
      const result = CompatibilityResult(
        kootas: [
          KootaScore(
            name: 'Varna',
            score: 1,
            maximum: 1,
            explanation: 'Traditional Varna matching.',
          ),
          KootaScore(
            name: 'Vashya',
            score: 2,
            maximum: 2,
            explanation: 'Traditional Vashya matching.',
          ),
          KootaScore(
            name: 'Tara',
            score: 3,
            maximum: 3,
            explanation: 'Traditional Tara matching.',
          ),
          KootaScore(
            name: 'Yoni',
            score: 4,
            maximum: 4,
            explanation: 'Traditional Yoni matching.',
          ),
          KootaScore(
            name: 'Graha Maitri',
            score: 5,
            maximum: 5,
            explanation: 'Traditional Graha Maitri matching.',
          ),
          KootaScore(
            name: 'Gana',
            score: 6,
            maximum: 6,
            explanation: 'Traditional Gana matching.',
          ),
          KootaScore(
            name: 'Bhakoot',
            score: 7,
            maximum: 7,
            explanation: 'Traditional Bhakoot matching.',
          ),
          KootaScore(
            name: 'Nadi',
            score: 8,
            maximum: 8,
            explanation: 'Traditional Nadi matching.',
          ),
        ],
        traditionalFlags: ['Review traditional Nadi considerations.'],
      );

      final bytes = await const CompatibilityPdfService().buildReport(
        brideName: 'Bride Test',
        groomName: 'Groom Test',
        result: result,
        reportDate: DateTime(2026, 10, 12),
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('generates a Hindi PDF with traditional flags', () async {
      const result = CompatibilityResult(
        kootas: [
          KootaScore(
            name: 'Varna',
            score: 1,
            maximum: 1,
            explanation: 'Traditional Varna matching.',
          ),
          KootaScore(
            name: 'Vashya',
            score: 2,
            maximum: 2,
            explanation: 'Traditional Vashya matching.',
          ),
          KootaScore(
            name: 'Tara',
            score: 3,
            maximum: 3,
            explanation: 'Traditional Tara matching.',
          ),
          KootaScore(
            name: 'Yoni',
            score: 4,
            maximum: 4,
            explanation: 'Traditional Yoni matching.',
          ),
          KootaScore(
            name: 'Graha Maitri',
            score: 5,
            maximum: 5,
            explanation: 'Traditional Graha Maitri matching.',
          ),
          KootaScore(
            name: 'Gana',
            score: 6,
            maximum: 6,
            explanation: 'Traditional Gana matching.',
          ),
          KootaScore(
            name: 'Bhakoot',
            score: 7,
            maximum: 7,
            explanation: 'Traditional Bhakoot matching.',
          ),
          KootaScore(
            name: 'Nadi',
            score: 8,
            maximum: 8,
            explanation: 'Traditional Nadi matching.',
          ),
        ],
        traditionalFlags: [
          'Traditional Nadi dosha flag: both nakshatras share a Nadi.',
          'Traditional Bhakoot dosha flag: signs have a 2/12, 5/9, '
              'or 6/8 relationship.',
        ],
      );

      final bytes = await const CompatibilityPdfService().buildReport(
        brideName: 'Bride Test',
        groomName: 'Groom Test',
        result: result,
        reportDate: DateTime(2026, 10, 14),
        language: CompatibilityReportLanguage.hindi,
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
