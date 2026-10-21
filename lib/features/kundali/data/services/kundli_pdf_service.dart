import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../l10n/app_localizations.dart';
import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/domain/entities/planet_dignity.dart';
import '../../../astrology/domain/entities/rashi_chart.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../../dasha/domain/entities/dasha_period.dart';
import '../../../dasha/domain/usecases/calculate_vimshottari_dasha.dart';
import '../../../dosha/domain/entities/kaal_sarp_result.dart';
import '../../../dosha/domain/entities/sade_sati.dart';
import '../../../dosha/domain/entities/zodiac_signs.dart';
import '../../../dosha/presentation/providers/dosha_provider.dart';
import '../../../gochar/domain/entities/transit.dart';
import '../../../numerology/domain/numerology.dart';
import '../../../remedies/domain/gemstone_recommendation.dart';
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
    // Load date names for the report language; outside the widget tree
    // (and in tests) nothing else has done this yet.
    await initializeDateFormatting(l10n.localeName);
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
    String signKey(String name) {
      final index = zodiacSignIndex(name);
      return index < 0 ? name : zodiacSigns[index];
    }

    final now = generatedAt ?? DateTime.now();
    final numerology = const Numerology()(
      dateOfBirth: data.dateOfBirth,
      name: data.name,
      year: now.year,
    );
    List<GemstoneRecommendation> gemstones;
    try {
      gemstones = recommendGemstones(kundali.ascendant);
    } on ArgumentError {
      gemstones = const [];
    }
    final antardashas = data.currentMahadasha == null
        ? const <DashaPeriod>[]
        : CalculateVimshottariDasha().antardashas(data.currentMahadasha!);
    final dashaLords = <(String, DashaPeriod)>[
      if (data.currentMahadasha case final maha?) ('mahadasha', maha),
      if (data.currentAntardasha case final antar?
          when antar.planet != data.currentMahadasha?.planet)
        ('antardasha', antar),
    ];
    final doshas = data.doshas;
    String kaalSarpLabel(DoshaReport report) =>
        switch (report.kaalSarp.status) {
          KaalSarpStatus.none => l10n.doshaStatus('none'),
          KaalSarpStatus.partial => l10n.doshaStatus('partial'),
          KaalSarpStatus.full => l10n.kaalSarpType(report.kaalSarp.type!.name),
        };

    final document = pw.Document(
      title: '${l10n.reportKundaliTitle} — ${data.name}',
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
                dates.format(now),
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
            l10n.reportKundaliTitle,
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
          pw.SizedBox(height: 10),
          note(l10n.reportIntro),

          heading(l10n.reportNatureTitle),
          subheading(l10n.reportLagnaHeading(sign(kundali.ascendant))),
          para(l10n.reportLagnaTraits(signKey(kundali.ascendant))),
          subheading(l10n.reportMoonHeading(sign(kundali.moonSign))),
          para(l10n.reportMoonTraits(signKey(kundali.moonSign))),

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

          heading(l10n.reportPlanetsTitle),
          for (final p in kundali.planets)
            if (p.house >= 1 && p.house <= 12)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  subheading(
                    switch (planetDignity(p.planet, p.sign)) {
                      PlanetDignity.neutral => l10n.reportPlanetHouse(
                        planet(p.planet),
                        p.house,
                      ),
                      final dignity =>
                        '${l10n.reportPlanetHouse(planet(p.planet), p.house)}'
                            '  ·  ${l10n.reportDignity(dignity.name)}',
                    },
                  ),
                  para(
                    l10n.reportPlanetEffect(
                      l10n.reportPlanetQualities(p.planet.toLowerCase()),
                      l10n.gocharHouseTheme('h${p.house}'),
                    ),
                  ),
                ],
              ),

          heading(l10n.yogasTitle),
          if (yogas.isEmpty)
            para(l10n.yogasNone)
          else
            for (final yoga in yogas)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  subheading(
                    yoga.cancelled
                        ? '${l10n.chartYogaName(yoga.id.name)} '
                              '(${l10n.chartYogaCancelled})'
                        : l10n.chartYogaName(yoga.id.name),
                  ),
                  para(l10n.chartYogaMeaning(yoga.id.name)),
                  note(
                    '${l10n.chartYogaRule(yoga.id.name)}  '
                    '(${yoga.planets.map(planet).join(' + ')})',
                  ),
                ],
              ),

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
            for (final (role, period) in dashaLords)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    subheading(
                      '${l10n.remediesPeriodRole(role)}: '
                      '${planet(period.planet.name)}',
                    ),
                    para(l10n.reportDashaTheme(period.planet.name)),
                  ],
                ),
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
            if (antardashas.isNotEmpty) ...[
              subheading(l10n.reportAntardashaTitle),
              pw.TableHelper.fromTextArray(
                headers: [
                  l10n.antardasha,
                  l10n.kundliReportFrom,
                  l10n.kundliReportTo,
                ],
                data: [
                  for (final period in antardashas)
                    [
                      period.contains(now)
                          ? '${planet(period.planet.name)} '
                                '(${l10n.dayDivisionNow})'
                          : planet(period.planet.name),
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
          ],

          if (doshas != null) ...[
            heading(l10n.doshaCheckTitle),
            subheading(
              '${l10n.manglikTitle}: '
              '${l10n.doshaStatus(doshas.manglik.status.name)}',
            ),
            para(l10n.manglikSummary(doshas.manglik.status.name)),
            for (final reason in doshas.manglik.cancellations)
              note('• ${l10n.manglikCancellation(reason.name)}'),
            note(
              l10n.manglikMarsPosition(
                sign(doshas.manglik.marsSign),
                doshas.manglik.marsHouseFromLagna,
                doshas.manglik.marsHouseFromMoon,
                doshas.manglik.marsHouseFromVenus,
              ),
            ),
            subheading('${l10n.kaalSarpTitle}: ${kaalSarpLabel(doshas)}'),
            para(switch (doshas.kaalSarp.status) {
              KaalSarpStatus.none => l10n.kaalSarpSummaryNone,
              KaalSarpStatus.full => l10n.kaalSarpSummaryFull(
                doshas.kaalSarp.rahuHouse,
                doshas.kaalSarp.ketuHouse,
              ),
              KaalSarpStatus.partial => l10n.kaalSarpSummaryPartial(
                doshas.kaalSarp.planetsOutside.map(planet).join(', '),
              ),
            }),
            if (doshas.kaalSarp.direction == KaalSarpDirection.ketuToRahu)
              note(l10n.kaalSarpAmritNote),
            subheading(l10n.sadeSatiTitle),
            note(l10n.sadeSatiBasis(sign(doshas.sadeSati.moonSign))),
            if (doshas.sadeSati.currentCycle case final cycle?) ...[
              para(
                doshas.sadeSati.currentPhase == null
                    ? l10n.sadeSatiPaused
                    : l10n.sadeSatiActive(
                        l10n.sadeSatiPhase(doshas.sadeSati.currentPhase!.name),
                      ),
              ),
              para(
                l10n.sadeSatiCurrentCycle(
                  dates.format(cycle.start),
                  dates.format(cycle.end),
                ),
              ),
              for (final phase in SadeSatiPhase.values)
                if (cycle.phaseStart(phase) case final start?)
                  note(
                    '${l10n.sadeSatiPhaseDetail(phase.name)} · '
                    '${l10n.sadeSatiPhaseFrom(dates.format(start))}',
                  ),
            ] else
              para(l10n.sadeSatiNotActive),
            if (doshas.sadeSati.currentDhaiya case final dhaiya?)
              para(l10n.shaniDhaiya(dhaiya.name)),
            if (doshas.sadeSati.nextCycle case final next?)
              note(
                l10n.sadeSatiNextCycle(
                  dates.format(next.start),
                  dates.format(next.end),
                ),
              ),
          ],

          heading(l10n.remediesTitle),
          note(l10n.remediesIntro),
          if (gemstones.isNotEmpty) ...[
            subheading(l10n.remediesGemsTitle),
            note(l10n.remediesGemsIntro),
            for (final stone in gemstones)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.all(8),
                decoration: const pw.BoxDecoration(color: _tint),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${l10n.remediesGemName(stone.planet.toLowerCase())}'
                      '  ·  ${planet(stone.planet)}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    note(
                      stone.roles
                          .map((r) => l10n.remediesGemRole(r.name))
                          .join(' · '),
                    ),
                    para(l10n.remediesGemWear(stone.planet.toLowerCase())),
                    note(
                      l10n.remediesSubstituteLabel(
                        l10n.remediesGemSubstitute(stone.planet.toLowerCase()),
                      ),
                    ),
                    if (stone.needsCaution)
                      note(l10n.remediesGemCaution(planet(stone.planet))),
                  ],
                ),
              ),
            note(l10n.remediesGemAdvice),
          ],
          if (dashaLords.isNotEmpty) ...[
            subheading(l10n.remediesPeriodsTitle),
            for (final (role, period) in dashaLords)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${l10n.remediesPeriodRole(role)}: '
                      '${planet(period.planet.name)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    para(l10n.remediesMantra(period.planet.name)),
                    note(l10n.remediesMantraLatin(period.planet.name)),
                    note(
                      l10n.remediesMantraHow(
                        l10n.remediesDay(period.planet.name),
                      ),
                    ),
                    para(
                      l10n.remediesCharity(
                        l10n.remediesCharityItems(period.planet.name),
                        l10n.remediesDay(period.planet.name),
                      ),
                    ),
                    para(
                      l10n.remediesDeity(
                        l10n.remediesDeityName(period.planet.name),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (doshas != null) ...[
            subheading(l10n.remediesDoshasTitle),
            if (doshas.manglik.isEffectivelyManglik)
              para(l10n.remediesManglik),
            if (doshas.sadeSati.isActive ||
                doshas.sadeSati.currentDhaiya != null)
              para(l10n.remediesSadeSati),
            if (doshas.kaalSarp.status != KaalSarpStatus.none)
              para(l10n.remediesKaalSarp),
            if (!doshas.manglik.isEffectivelyManglik &&
                !doshas.sadeSati.isActive &&
                doshas.sadeSati.currentDhaiya == null &&
                doshas.kaalSarp.status == KaalSarpStatus.none)
              para(l10n.remediesNoDoshas),
          ],
          note(l10n.remediesDisclaimer),

          heading(l10n.numerologyTitle),
          subheading(
            '${l10n.numerologyMulank}: ${numerology.mulank}  ·  '
            '${l10n.numerologyRuledBy(planet(Numerology.rulingPlanet[numerology.mulank] ?? ''))}',
          ),
          para(l10n.numerologyTraits('n${numerology.mulank}')),
          subheading(
            '${l10n.numerologyBhagyank}: ${numerology.bhagyank}  ·  '
            '${l10n.numerologyRuledBy(planet(Numerology.rulingPlanet[numerology.bhagyank] ?? ''))}',
          ),
          para(l10n.numerologyTraits('n${numerology.bhagyank}')),
          subheading(
            l10n.numerologyPersonalYear(
              '${numerology.year}',
              numerology.personalYear,
            ),
          ),
          para(l10n.numerologyYearTheme('n${numerology.personalYear}')),
          note(
            l10n.numerologyLucky(
              l10n.numerologyLuckyDay('n${numerology.mulank}'),
              l10n.numerologyLuckyColour('n${numerology.mulank}'),
            ),
          ),

          if (data.transits != null && data.transits!.current.isNotEmpty) ...[
            heading(l10n.gocharTitle),
            for (final reading in data.transits!.current)
              fact(
                l10n.gocharPlanetIn(
                  planet(reading.planet.displayKey),
                  sign(zodiacSigns[reading.signIndex]),
                ),
                '${l10n.gocharHouseFromMoon(reading.houseFromMoon)} · '
                '${l10n.gocharTone(reading.tone.name)} · '
                '${l10n.gocharHouseTheme('h${reading.houseFromMoon}')}',
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
