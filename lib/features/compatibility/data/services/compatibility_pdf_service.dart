import 'package:flutter/services.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/compatibility_result.dart';

/// Language options for the exported marriage-compatibility report.
enum CompatibilityReportLanguage { english, hindi }

/// Builds a shareable PDF for a traditional Ashtakoota compatibility result.
class CompatibilityPdfService {
  const CompatibilityPdfService();

  Future<Uint8List> buildReport({
    required String brideName,
    required String groomName,
    required CompatibilityResult result,
    DateTime? reportDate,
    CompatibilityReportLanguage language = CompatibilityReportLanguage.english,
  }) async {
    final date = reportDate ?? DateTime.now();
    final hindi = language == CompatibilityReportLanguage.hindi;

    String kootaName(String name) {
      if (!hindi) return name;
      const names = {
        'Varna': 'वर्ण',
        'Vashya': 'वश्य',
        'Tara': 'तारा',
        'Yoni': 'योनि',
        'Graha Maitri': 'ग्रह मैत्री',
        'Gana': 'गण',
        'Bhakoot': 'भकूट',
        'Nadi': 'नाड़ी',
      };
      return names[name] ?? name;
    }

    String explanationFor(String name, String original) {
      if (!hindi) return original;
      const explanations = {
        'Varna': 'परंपरागत वर्ण मिलान के आधार पर प्राप्त अंक।',
        'Vashya': 'परंपरागत वश्य मिलान के आधार पर प्राप्त अंक।',
        'Tara': 'दोनों नक्षत्रों की दूरी और तारा मिलान पर आधारित अंक।',
        'Yoni': 'परंपरागत योनि मिलान के आधार पर प्राप्त अंक।',
        'Graha Maitri': 'चंद्र राशियों के स्वामियों की मैत्री पर आधारित अंक।',
        'Gana': 'देव, मनुष्य और राक्षस गण के परंपरागत मिलान पर आधारित अंक।',
        'Bhakoot':
            'राशियों के बीच परंपरागत 2/12, 5/9 और 6/8 संबंधों पर आधारित अंक।',
        'Nadi': 'दोनों नक्षत्रों की नाड़ी के परंपरागत मिलान पर आधारित अंक।',
      };
      return explanations[name] ?? original;
    }

    String flagText(String flag) {
      if (!hindi) return flag;
      if (flag.startsWith('Traditional Nadi dosha flag:')) {
        return 'परंपरागत नाड़ी दोष संकेत: दोनों नक्षत्रों की नाड़ी समान है।';
      }
      if (flag.startsWith('Traditional Bhakoot dosha flag:')) {
        return 'परंपरागत भकूट दोष संकेत: राशियों में 2/12, 5/9 या 6/8 का संबंध है।';
      }
      return flag;
    }

    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansDevanagari.ttf',
    );
    final devanagariFont = pw.Font.ttf(fontData);
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: devanagariFont, bold: devanagariFont),
    );

    String scoreText(double score) {
      return score == score.roundToDouble()
          ? score.toStringAsFixed(0)
          : score.toStringAsFixed(1);
    }

    final dateText =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            hindi
                ? 'पृष्ठ ${context.pageNumber} / ${context.pagesCount}'
                : 'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        build: (context) => [
          pw.Text(
            hindi ? 'विवाह अनुकूलता रिपोर्ट' : 'Marriage Compatibility Report',
            style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            hindi ? 'अष्टकूट गुण मिलान' : 'Ashtakoota Guna Milan',
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            hindi ? 'रिपोर्ट की तारीख: $dateText' : 'Report date: $dateText',
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(hindi ? 'वधू: $brideName' : 'Bride: $brideName'),
                pw.SizedBox(height: 5),
                pw.Text(hindi ? 'वर: $groomName' : 'Groom: $groomName'),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            '${hindi ? 'कुल गुण' : 'Overall score'}: '
            '${scoreText(result.totalScore)} / '
            '${scoreText(result.maximumScore)}',
            style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            result.meetsTraditionalMinimum
                ? (hindi
                      ? 'परंपरागत 18 गुणों की सीमा पूरी होती है'
                      : 'Meets the traditional 18-point threshold')
                : (hindi
                      ? 'परंपरागत 18 गुणों की सीमा से कम'
                      : 'Below the traditional 18-point threshold'),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  hindi ? 'अंक कैसे समझें' : 'How to read this score',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  hindi
                      ? 'कुल अंक आठ पारंपरिक कूटों के आधार पर निकाले जाते हैं। '
                            '18 अंकों की सीमा एक पारंपरिक मार्गदर्शक है, '
                            'विवाह की सफलता का निर्णायक माप नहीं। प्रत्येक कूट '
                            'का महत्व और व्याख्या परंपरा के अनुसार अलग हो सकती है।'
                      : 'The total reflects the traditional points assigned '
                            'across eight Kootas. The 18-point benchmark is a '
                            'traditional guideline, not a definitive measure of '
                            'marital success. The interpretation and importance '
                            'of individual Kootas can vary by tradition.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            hindi ? 'अष्टकूट विवरण' : 'Eight Kootas',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: hindi
                ? ['कूट', 'अंक', 'प्रतिशत', 'विवरण']
                : ['Koota', 'Score', 'Points earned (%)', 'Explanation'],
            data: result.kootas
                .map(
                  (koota) => [
                    kootaName(koota.name),
                    '${scoreText(koota.score)} / '
                        '${scoreText(koota.maximum)}',
                    '${scoreText(koota.percentage)}%',
                    explanationFor(koota.name, koota.explanation),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 5,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.0),
              1: const pw.FlexColumnWidth(1.0),
              2: const pw.FlexColumnWidth(1.1),
              3: const pw.FlexColumnWidth(3.2),
            },
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
          ),
          if (result.traditionalFlags.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              hindi
                  ? 'ध्यान देने योग्य पारंपरिक संकेत'
                  : 'Traditional flags to review',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            ...result.traditionalFlags.map(
              (flag) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Bullet(text: flagText(flag)),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              hindi
                  ? 'ये संकेत अंतिम निर्णय नहीं हैं। इनकी व्याख्या, अपवाद और उपाय परंपरा के अनुसार अलग हो सकते हैं।'
                  : 'Flags are not a final verdict. Interpretations, exceptions, and remedies vary by tradition.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey500),
          pw.Text(
            hindi ? 'महत्वपूर्ण अस्वीकरण' : 'Important disclaimer',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            hindi
                ? 'यह केवल पारंपरिक ज्योतिषीय व्याख्या है। यह अंक संबंध की गुणवत्ता या सफलता का वैज्ञानिक रूप से प्रमाणित अनुमान नहीं है। परंपरा-विशिष्ट व्याख्या के लिए योग्य ज्योतिषी से परामर्श करें।'
                : 'Traditional astrology interpretation only. This score is not a scientifically validated prediction of relationship quality or success. Consult a qualified practitioner for tradition-specific interpretations.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );

    return document.save();
  }
}
