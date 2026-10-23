import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../l10n/app_localizations.dart';
import '../astrology/presentation/utils/astrology_localization.dart';
import '../dosha/domain/entities/zodiac_signs.dart';
import 'varshphal.dart';

/// Builds the Varshphal (year ahead) PDF. The bundled font covers Latin and
/// Devanagari, so the report is in English, Hindi or Marathi.
class VarshphalPdfService {
  const VarshphalPdfService();

  static const _accent = PdfColor.fromInt(0xFF8A5A00);
  static const _rule = PdfColor.fromInt(0xFFD9D2C3);
  static const _tint = PdfColor.fromInt(0xFFFBF6EA);

  /// Report language for an app language code.
  static String reportLanguage(String appLanguage) =>
      const {'hi', 'mr'}.contains(appLanguage) ? appLanguage : 'en';

  Future<Uint8List> buildReport({
    required String name,
    required String place,
    required Varshphal varshphal,
    String languageCode = 'en',
    DateTime? reportDate,
  }) async {
    final l10n = lookupAppLocalizations(Locale(languageCode));
    await initializeDateFormatting(l10n.localeName);
    final dates = DateFormat.yMMMd(l10n.localeName);
    final moment = DateFormat.yMMMd(l10n.localeName).add_jm();
    final v = varshphal;

    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansDevanagari.ttf'),
    );
    final document = pw.Document(
      title: '${l10n.varshphalTitle} — $name',
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        fontFallback: [pw.Font.helvetica()],
      ),
    );

    String signName(int index) => l10n.rashiName(zodiacSigns[index]);
    String theme(int house) => l10n.gocharHouseTheme('h$house');

    pw.Widget heading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: _accent,
        ),
      ),
    );
    pw.Widget para(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10.5)),
    );
    pw.Widget note(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              l10n.kundliReportGenerated(
                dates.format(reportDate ?? DateTime.now()),
              ),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          pw.Text(
            l10n.varshphalTitle,
            style: const pw.TextStyle(fontSize: 12, color: _accent),
          ),
          pw.Text(
            name,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          para(l10n.varshphalAge(v.completedYears + 1)),
          para(l10n.varshphalPravesh(moment.format(v.praveshLocal))),
          note('${l10n.placeOfBirth}: $place'),

          heading(l10n.varshphalMuntha),
          para(l10n.varshphalMunthaLine(signName(v.munthaSign), v.munthaHouse)),
          para(l10n.varshphalTheme(theme(v.munthaHouse))),
          para(l10n.varshphalTone(v.tone.name)),
          para(l10n.varshphalMunthaLord(l10n.planetName(v.munthaLord))),

          heading(l10n.varshphalChart),
          para(
            l10n.varshphalLagna(
              signName(v.lagnaSign),
              l10n.planetName(v.lagnaLord),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [l10n.planet, l10n.sign, l10n.house, ''],
            data: [
              for (final (planet, sign, house) in v.placements)
                [
                  l10n.planetName(planet),
                  l10n.rashiName(sign),
                  '$house',
                  theme(house),
                ],
            ],
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(0.6),
              3: pw.FlexColumnWidth(3),
            },
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            headerDecoration: const pw.BoxDecoration(color: _tint),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            cellAlignment: pw.Alignment.topLeft,
            headerAlignment: pw.Alignment.centerLeft,
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
              bottom: pw.BorderSide(color: _rule, width: 0.5),
            ),
          ),

          if (v.months.isNotEmpty) ...[
            heading(l10n.varshphalMonths),
            for (final (start, house) in v.months)
              para(
                '${dates.format(start)}  ·  '
                '${l10n.varshphalPlanetLine(house, theme(house))}',
              ),
          ],

          pw.SizedBox(height: 20),
          pw.Divider(color: _rule),
          note(l10n.varshphalNote),
          note(l10n.kundliReportDisclaimer),
        ],
      ),
    );

    return document.save();
  }
}
