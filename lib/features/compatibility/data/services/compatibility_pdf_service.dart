import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../l10n/app_localizations.dart';
import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../../dosha/domain/entities/manglik_result.dart';
import '../../domain/entities/compatibility_result.dart';
import '../../domain/entities/koota_score.dart';

/// Language options for the exported marriage-compatibility report. The
/// bundled font covers Latin and Devanagari scripts.
enum CompatibilityReportLanguage {
  english('en'),
  hindi('hi'),
  marathi('mr');

  final String code;

  const CompatibilityReportLanguage(this.code);
}

/// One partner's details for the report. [kundali] and [manglik] are
/// optional so a report can still be made from the scores alone.
class CompatibilityReportPerson {
  final String name;
  final DateTime? dateOfBirth;
  final String? birthTime;
  final String? place;
  final Kundali? kundali;
  final ManglikResult? manglik;

  const CompatibilityReportPerson({
    required this.name,
    this.dateOfBirth,
    this.birthTime,
    this.place,
    this.kundali,
    this.manglik,
  });
}

/// Score bands used for the overall reading (out of 36).
enum CompatibilityBand {
  excellent,
  good,
  average,
  low;

  static CompatibilityBand of(double score) => score >= 28
      ? excellent
      : score >= 24
      ? good
      : score >= 18
      ? average
      : low;
}

/// How fully a Koota scored: all, some or none of its points.
String kootaLevel(KootaScore koota) => koota.score >= koota.maximum
    ? 'full'
    : koota.score <= 0
    ? 'none'
    : 'partial';

/// ARB select key for a Koota name from the domain ('Graha Maitri' →
/// 'grahaMaitri').
String kootaKey(String name) {
  final words = name.trim().toLowerCase().split(RegExp(r'\s+'));
  return words.first +
      words.skip(1).map((w) => w[0].toUpperCase() + w.substring(1)).join();
}

/// 'nadi' or 'bhakoot' for the calculation's flag text, else null.
String? flagKey(String flag) {
  if (flag.startsWith('Traditional Nadi')) return 'nadi';
  if (flag.startsWith('Traditional Bhakoot')) return 'bhakoot';
  return null;
}

/// Builds the Detailed Compatibility analysis PDF report.
class CompatibilityPdfService {
  const CompatibilityPdfService();

  static const _accent = PdfColor.fromInt(0xFF8A5A00);
  static const _rule = PdfColor.fromInt(0xFFD9D2C3);
  static const _tint = PdfColor.fromInt(0xFFFBF6EA);

  Future<Uint8List> buildReport({
    required CompatibilityReportPerson bride,
    required CompatibilityReportPerson groom,
    required CompatibilityResult result,
    DateTime? reportDate,
    CompatibilityReportLanguage language = CompatibilityReportLanguage.english,
  }) async {
    final l10n = lookupAppLocalizations(Locale(language.code));
    final generated = reportDate ?? DateTime.now();
    await initializeDateFormatting(l10n.localeName);
    final dates = DateFormat.yMMMd(l10n.localeName);

    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansDevanagari.ttf',
    );
    final font = pw.Font.ttf(fontData);
    final document = pw.Document(
      title: '${l10n.reportCompatTitle} — ${bride.name} & ${groom.name}',
      // Helvetica covers punctuation (°, ·, –) missing from the Devanagari
      // font.
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        fontFallback: [pw.Font.helvetica()],
      ),
    );

    String score(double value) => value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    String sign(String name) => l10n.rashiName(name);
    // English keeps the calculation's own wording.
    String flagText(String flag) {
      final key = flagKey(flag);
      if (key == null || l10n.localeName.startsWith('en')) return flag;
      return l10n.compatFlag(key);
    }

    final band = CompatibilityBand.of(result.totalScore);
    final strengths = [
      for (final k in result.kootas)
        if (kootaLevel(k) == 'full') k,
    ];
    final weak = [
      for (final k in result.kootas)
        if (kootaLevel(k) == 'none') k,
    ];
    final flaggedKeys = {
      for (final flag in result.traditionalFlags) ?flagKey(flag),
    };
    final manglikMatch = bride.manglik != null && groom.manglik != null
        ? compareManglik(bride.manglik!, groom.manglik!)
        : null;

    pw.Widget heading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: _accent,
        ),
      ),
    );
    pw.Widget subheading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
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
    pw.Widget table(
      List<String> headers,
      List<List<String>> rows, {
      Map<int, pw.TableColumnWidth>? widths,
    }) => pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      columnWidths: widths,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: _tint),
      cellStyle: const pw.TextStyle(fontSize: 9.5),
      cellAlignment: pw.Alignment.topLeft,
      headerAlignment: pw.Alignment.centerLeft,
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
        bottom: pw.BorderSide(color: _rule, width: 0.5),
      ),
    );

    String detail(CompatibilityReportPerson p, String Function(Kundali) f) =>
        p.kundali == null ? '—' : f(p.kundali!);

    final chartRows = <List<String>>[
      [
        l10n.dateOfBirth,
        ...[bride, groom].map((p) => _orDash(p.dateOfBirth, dates.format)),
      ],
      [l10n.exactBirthTime, ...[bride, groom].map((p) => p.birthTime ?? '—')],
      [l10n.placeOfBirth, ...[bride, groom].map((p) => p.place ?? '—')],
      [
        l10n.ascendant,
        ...[bride, groom].map((p) => detail(p, (k) => sign(k.ascendant))),
      ],
      [
        l10n.moonSign,
        ...[bride, groom].map((p) => detail(p, (k) => sign(k.moonSign))),
      ],
      [
        l10n.nakshatra,
        ...[bride, groom].map(
          (p) => detail(
            p,
            (k) =>
                '${l10n.nakshatraName(k.nakshatra)}, '
                '${l10n.pada} ${k.nakshatraPada}',
          ),
        ),
      ],
      if (bride.manglik != null || groom.manglik != null)
        [
          l10n.compatManglikTitle,
          ...[bride, groom].map(
            (p) => p.manglik == null
                ? '—'
                : l10n.compatManglikStatus(p.manglik!.status.name),
          ),
        ],
    ];

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              l10n.kundliReportGenerated(dates.format(generated)),
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
            l10n.reportCompatTitle,
            style: const pw.TextStyle(fontSize: 12, color: _accent),
          ),
          pw.Text(
            '${bride.name}  &  ${groom.name}',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          note(l10n.reportCompatIntro(bride.name, groom.name)),

          heading(l10n.reportCompatCharts),
          table(
            [
              '',
              '${l10n.compatPerson('bride')}: ${bride.name}',
              '${l10n.compatPerson('groom')}: ${groom.name}',
            ],
            chartRows,
            widths: const {
              0: pw.FlexColumnWidth(1.1),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
            },
          ),

          heading(l10n.compatScoreLabel),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _tint,
              border: pw.Border.all(color: _rule),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${score(result.totalScore)} / ${score(result.maximumScore)}',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _accent,
                  ),
                ),
                pw.SizedBox(height: 4),
                para(l10n.reportCompatBand(band.name)),
              ],
            ),
          ),

          heading(l10n.compatEightKootas),
          table(
            [
              l10n.reportColKoota,
              l10n.reportColPoints,
              l10n.reportColArea,
              l10n.reportColResult,
            ],
            [
              for (final k in result.kootas)
                [
                  l10n.kootaName(kootaKey(k.name)),
                  '${score(k.score)} / ${score(k.maximum)}',
                  l10n.reportKootaArea(kootaKey(k.name)),
                  l10n.reportKootaLevel(kootaLevel(k)),
                ],
            ],
            widths: const {
              0: pw.FlexColumnWidth(1.2),
              1: pw.FlexColumnWidth(0.8),
              2: pw.FlexColumnWidth(2.6),
              3: pw.FlexColumnWidth(1.1),
            },
          ),
          note(l10n.compatInsightsBody),

          if (strengths.isNotEmpty) ...[
            subheading(l10n.reportCompatStrengths),
            for (final k in strengths)
              para(
                '• ${l10n.kootaName(kootaKey(k.name))}: '
                '${l10n.reportKootaArea(kootaKey(k.name))}',
              ),
          ],
          if (weak.isNotEmpty) ...[
            subheading(l10n.reportCompatWatch),
            for (final k in weak)
              para(
                '• ${l10n.kootaName(kootaKey(k.name))}: '
                '${l10n.reportKootaArea(kootaKey(k.name))}',
              ),
          ],

          if (result.traditionalFlags.isNotEmpty) ...[
            heading(l10n.compatFlagsTitle),
            for (final flag in result.traditionalFlags)
              para('• ${flagText(flag)}'),
            note(l10n.compatFlagsNote),
            if (flaggedKeys.isNotEmpty) ...[
              subheading(l10n.reportCompatRemediesTitle),
              for (final key in flaggedKeys) para(l10n.reportCompatRemedy(key)),
            ],
          ],

          if (manglikMatch != null) ...[
            heading(l10n.compatManglikTitle),
            para(switch (manglikMatch) {
              ManglikMatch.neitherManglik => l10n.compatManglikNeither,
              ManglikMatch.bothManglik => l10n.compatManglikBoth,
              ManglikMatch.onlyOneManglik => l10n.compatManglikOnlyOne,
            }),
            for (final (role, person) in [('bride', bride), ('groom', groom)])
              if (person.manglik case final manglik?) ...[
                subheading(
                  l10n.compatManglikPerson(
                    '${l10n.compatPerson(role)} (${person.name})',
                    l10n.compatManglikStatus(manglik.status.name),
                  ),
                ),
                note(l10n.manglikSummary(manglik.status.name)),
              ],
          ],

          pw.SizedBox(height: 20),
          pw.Divider(color: _rule),
          note(l10n.compatDisclaimer),
        ],
      ),
    );

    return document.save();
  }

  static String _orDash(DateTime? value, String Function(DateTime) format) =>
      value == null ? '—' : format(value);
}
