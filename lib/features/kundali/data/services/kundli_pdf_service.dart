import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../l10n/app_localizations.dart';
import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/domain/entities/rashi_chart.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../../dasha/domain/entities/dasha_period.dart';
import '../../../dosha/domain/entities/kaal_sarp_result.dart';
import '../../../dosha/domain/entities/zodiac_signs.dart';
import '../../../dosha/presentation/providers/dosha_provider.dart';
import '../../../gochar/domain/entities/transit.dart';
import '../../../yogas/domain/entities/yoga.dart';
import '../../../yogas/domain/usecases/detect_yogas.dart';
import '../../domain/usecases/calculate_navamsa.dart';

/// Everything the Kundli report shows, gathered by the caller.
class KundliReportData {
  final String name;
  final DateTime dateOfBirth;
  final String birthTime;
  final String place;
  final Kundali kundali;
  final List<DashaPeriod> mahadashas;
  final DashaPeriod? currentMahadasha;
  final DashaPeriod? currentAntardasha;
  final DoshaReport? doshas;
  final GocharReport? transits;

  const KundliReportData({
    required this.name,
    required this.dateOfBirth,
    required this.birthTime,
    required this.place,
    required this.kundali,
    this.mahadashas = const [],
    this.currentMahadasha,
    this.currentAntardasha,
    this.doshas,
    this.transits,
  });
}

/// Builds a printable multi-page Kundli report. Uses the bundled Noto Sans
/// Devanagari font, which covers both English and Hindi.
class KundliPdfService {
  const KundliPdfService();

  static const _accent = PdfColor.fromInt(0xFF8A5A00);
  static const _rule = PdfColor.fromInt(0xFFD9D2C3);
  static const _tint = PdfColor.fromInt(0xFFFBF6EA);

  Future<Uint8List> build(
    KundliReportData data,
    AppLocalizations l10n, {
    DateTime? generatedAt,
  }) async {
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansDevanagari.ttf',
    );
    final font = pw.Font.ttf(fontData);
    final dates = DateFormat.yMMMd(l10n.localeName);
    final kundali = data.kundali;
    final navamsa = const CalculateNavamsa()(kundali);
    List<YogaResult> yogas;
    try {
      yogas = const DetectYogas()(kundali);
    } on ArgumentError {
      yogas = const [];
    }

    String planet(String name) => l10n.planetName(_capitalize(name));
    String sign(String name) => l10n.rashiName(name);

    final document = pw.Document(
      title: '${l10n.kundliReportTitle} — ${data.name}',
      // Helvetica covers punctuation (°, ·, –) missing from the Devanagari
      // font.
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        fontFallback: [pw.Font.helvetica()],
      ),
    );

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

    pw.Widget fact(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: const pw.TextStyle(color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
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
                dates.format(generatedAt ?? DateTime.now()),
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
            l10n.kundliReportTitle,
            style: const pw.TextStyle(fontSize: 12, color: _accent),
          ),
          pw.Text(
            data.name,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          fact(l10n.dateOfBirth, dates.format(data.dateOfBirth)),
          fact(l10n.exactBirthTime, data.birthTime),
          fact(l10n.placeOfBirth, data.place),
          pw.SizedBox(height: 6),
          fact(
            l10n.ascendant,
            '${sign(kundali.ascendant)} '
            '${kundali.ascendantDegree.toStringAsFixed(2)}°',
          ),
          fact(l10n.moonSign, sign(kundali.moonSign)),
          fact(l10n.sunSign, sign(kundali.sunSign)),
          fact(
            l10n.nakshatra,
            '${l10n.nakshatraName(kundali.nakshatra)}, '
            '${l10n.pada} ${kundali.nakshatraPada}',
          ),

          heading('${l10n.chartD1}  ·  ${l10n.chartD9}'),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (kundali.rashiChart != null)
                pw.Expanded(
                  child: _chart(kundali.rashiChart!, l10n, planet),
                ),
              pw.SizedBox(width: 16),
              pw.Expanded(child: _chart(navamsa.chart, l10n, planet)),
            ],
          ),

          heading(l10n.planetaryPositions),
          pw.TableHelper.fromTextArray(
            headers: [
              l10n.planet,
              l10n.sign,
              l10n.house,
              l10n.degree,
              l10n.nakshatra,
            ],
            data: [
              for (final p in kundali.planets)
                [
                  p.retrograde
                      ? '${planet(p.planet)} (${l10n.retrograde})'
                      : planet(p.planet),
                  sign(p.sign),
                  '${p.house}',
                  p.formattedDegree,
                  p.nakshatra == null
                      ? '—'
                      : '${l10n.nakshatraName(p.nakshatra!)} '
                            '${p.nakshatraPada ?? ''}',
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: _tint),
            cellStyle: const pw.TextStyle(fontSize: 10),
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
              bottom: pw.BorderSide(color: _rule, width: 0.5),
            ),
          ),

          if (yogas.isNotEmpty) ...[
            heading(l10n.yogasTitle),
            for (final yoga in yogas)
              fact(
                yoga.cancelled
                    ? '${l10n.chartYogaName(yoga.id.name)} '
                          '(${l10n.chartYogaCancelled})'
                    : l10n.chartYogaName(yoga.id.name),
                yoga.planets.map(planet).join(' + '),
              ),
          ],

          if (data.mahadashas.isNotEmpty) ...[
            heading(l10n.vimshottariDasha),
            if (data.currentMahadasha != null)
              fact(
                l10n.mahadasha,
                '${planet(data.currentMahadasha!.planet.name)} · '
                '${dates.format(data.currentMahadasha!.startDate)} – '
                '${dates.format(data.currentMahadasha!.endDate)}',
              ),
            if (data.currentAntardasha != null)
              fact(
                l10n.antardasha,
                '${planet(data.currentAntardasha!.planet.name)} · '
                '${dates.format(data.currentAntardasha!.startDate)} – '
                '${dates.format(data.currentAntardasha!.endDate)}',
              ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: [
                l10n.mahadasha,
                l10n.kundliReportFrom,
                l10n.kundliReportTo,
              ],
              data: [
                for (final period in data.mahadashas)
                  [
                    planet(period.planet.name),
                    dates.format(period.startDate),
                    dates.format(period.endDate),
                  ],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: _tint),
              cellStyle: const pw.TextStyle(fontSize: 10),
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
                bottom: pw.BorderSide(color: _rule, width: 0.5),
              ),
            ),
          ],

          if (data.doshas != null) ...[
            heading(l10n.doshaCheckTitle),
            fact(
              l10n.manglikTitle,
              l10n.doshaStatus(data.doshas!.manglik.status.name),
            ),
            pw.Text(
              l10n.manglikSummary(data.doshas!.manglik.status.name),
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 6),
            fact(
              l10n.kaalSarpTitle,
              switch (data.doshas!.kaalSarp.status) {
                KaalSarpStatus.none => l10n.doshaStatus('none'),
                KaalSarpStatus.partial => l10n.doshaStatus('partial'),
                KaalSarpStatus.full => l10n.kaalSarpType(
                  data.doshas!.kaalSarp.type!.name,
                ),
              },
            ),
            pw.SizedBox(height: 6),
            fact(
              l10n.sadeSatiTitle,
              data.doshas!.sadeSati.currentCycle != null
                  ? l10n.sadeSatiCurrentCycle(
                      dates.format(data.doshas!.sadeSati.currentCycle!.start),
                      dates.format(data.doshas!.sadeSati.currentCycle!.end),
                    )
                  : data.doshas!.sadeSati.nextCycle != null
                  ? l10n.sadeSatiNextCycle(
                      dates.format(data.doshas!.sadeSati.nextCycle!.start),
                      dates.format(data.doshas!.sadeSati.nextCycle!.end),
                    )
                  : l10n.sadeSatiNotActive,
            ),
          ],

          if (data.transits != null && data.transits!.current.isNotEmpty) ...[
            heading(l10n.gocharTitle),
            for (final reading in data.transits!.current)
              fact(
                l10n.gocharPlanetIn(
                  planet(reading.planet.displayKey),
                  sign(zodiacSigns[reading.signIndex]),
                ),
                '${l10n.gocharHouseFromMoon(reading.houseFromMoon)} · '
                '${l10n.gocharTone(reading.tone.name)}',
              ),
          ],

          pw.SizedBox(height: 24),
          pw.Text(
            l10n.kundliReportDisclaimer,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return document.save();
  }

  /// South Indian layout: signs fixed in a 4×4 ring, Lagna cell shaded.
  pw.Widget _chart(
    RashiChart chart,
    AppLocalizations l10n,
    String Function(String) planet,
  ) {
    const cells = [
      (0, 1), (0, 2), (0, 3), (1, 3), (2, 3), (3, 3),
      (3, 2), (3, 1), (3, 0), (2, 0), (1, 0), (0, 0),
    ];
    final lagna = chart.house(1);
    final lagnaIndex = lagna == null ? -1 : zodiacSignIndex(lagna.sign);

    RashiHouse? houseFor(int signIndex) {
      for (final h in chart.houses) {
        if (zodiacSignIndex(h.sign) == signIndex) return h;
      }
      return null;
    }

    const size = 240.0;
    const cell = size / 4;

    return pw.SizedBox(
      width: size,
      height: size,
      child: pw.Stack(
        children: [
          for (var s = 0; s < 12; s++)
            pw.Positioned(
              left: cells[s].$2 * cell,
              top: cells[s].$1 * cell,
              child: pw.Container(
                width: cell,
                height: cell,
                padding: const pw.EdgeInsets.all(3),
                decoration: pw.BoxDecoration(
                  color: s == lagnaIndex ? _tint : null,
                  border: pw.Border.all(color: _rule, width: 0.6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      s == lagnaIndex
                          ? '${l10n.rashiName(zodiacSigns[s])} · '
                                '${l10n.chartLagnaMark}'
                          : l10n.rashiName(zodiacSigns[s]),
                      style: const pw.TextStyle(
                        fontSize: 6.5,
                        color: PdfColors.grey700,
                      ),
                    ),
                    for (final p in houseFor(s)?.planets ?? const [])
                      pw.Text(
                        planet(p.planet),
                        style: const pw.TextStyle(fontSize: 7.5),
                      ),
                  ],
                ),
              ),
            ),
          pw.Positioned(
            left: cell,
            top: cell,
            child: pw.Container(
              width: cell * 2,
              height: cell * 2,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _rule, width: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String value) => value.isEmpty
      ? value
      : value[0].toUpperCase() + value.substring(1).toLowerCase();
}
