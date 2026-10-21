import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/vastu_zone.dart';
import '../../presentation/utils/vastu_localization.dart';
import '../domain/vastu_analysis.dart';
import '../domain/vastu_layout.dart';
import '../presentation/vastu_layout_text.dart';

/// Builds the Detailed Vastu report for one property.
class VastuReportPdfService {
  const VastuReportPdfService();

  static const _accent = PdfColor.fromInt(0xFF8A5A00);
  static const _rule = PdfColor.fromInt(0xFFD9D2C3);
  static const _tint = PdfColor.fromInt(0xFFFBF6EA);
  static const _red = PdfColor.fromInt(0xFFC0392B);
  static const _green = PdfColor.fromInt(0xFF2E8B57);
  static const _amber = PdfColor.fromInt(0xFFD08A00);

  Future<Uint8List> build({
    required VastuLayout layout,
    required AppLocalizations l10n,
    Uint8List? planImage,
    DateTime? generatedAt,
  }) async {
    final analysis = VastuAnalysis.of(layout);
    final now = generatedAt ?? DateTime.now();
    await initializeDateFormatting(l10n.localeName);
    final dates = DateFormat.yMMMd(l10n.localeName);

    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansDevanagari.ttf'),
    );
    final document = pw.Document(
      title: '${l10n.vastuReportTitle} — ${layout.name}',
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        fontFallback: [pw.Font.helvetica()],
      ),
    );

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
    pw.Widget para(String text, {PdfColor? color, double size = 10.5}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            text,
            style: pw.TextStyle(fontSize: size, color: color),
          ),
        );
    pw.Widget note(String text) =>
        para(text, color: PdfColors.grey700, size: 9);
    pw.Widget table(
      List<String> headers,
      List<List<String>> rows, {
      Map<int, pw.TableColumnWidth>? widths,
    }) => pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      columnWidths: widths,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
      headerDecoration: const pw.BoxDecoration(color: _tint),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.topLeft,
      headerAlignment: pw.Alignment.centerLeft,
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
        bottom: pw.BorderSide(color: _rule, width: 0.5),
      ),
    );

    String fitLabel(ZoneFit fit) => l10n.vastuFit(fit.name);
    final minor = analysis.doshas.length - analysis.majorCount;
    final entrance = l10n.padaLabel(analysis.entrancePada);
    final markNumber = {
      for (var i = 0; i < analysis.rooms.length; i++)
        analysis.rooms[i].mark.id: i + 1,
    };

    final zoneRows = <List<String>>[
      for (final zone in VastuZone.values)
        [
          '${zone.abbreviation} · ${l10n.vastuZoneName(zone.name)}',
          l10n.vastuZoneTheme(zone.name),
          _roomsIn(analysis, ZonePlace(zone), l10n),
        ],
      [
        l10n.vastuBrahmasthan,
        l10n.vastuDoshaCentre,
        _roomsIn(analysis, const ZonePlace(null), l10n),
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
              l10n.kundliReportGenerated(dates.format(now)),
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
            l10n.vastuReportTitle,
            style: const pw.TextStyle(fontSize: 12, color: _accent),
          ),
          pw.Text(
            layout.name,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _tint,
              border: pw.Border.all(color: _rule),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      l10n.vastuScoreTitle,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      '${analysis.score} / 100',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: _accent,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      para(l10n.vastuScoreBand(analysis.band.name)),
                      note(l10n.vastuDoshaCounts(analysis.majorCount, minor)),
                      note(
                        '${l10n.vastuEntranceResult(entrance)} · '
                        '${localizedVastuLevel(l10n, analysis.entranceLevel)}',
                      ),
                      note(l10n.facingLabel(layout.entranceFacing)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          heading(l10n.vastuGridTitle),
          pw.Center(child: _plan(layout, analysis, planImage, markNumber)),
          pw.SizedBox(height: 6),
          if (analysis.rooms.isNotEmpty)
            table(
              [
                '#',
                l10n.vastuPlanStepRooms,
                l10n.vastuReportZoneColumn,
                l10n.vastuPlacementsTitle,
              ],
              [
                for (final r in analysis.rooms)
                  [
                    '${markNumber[r.mark.id]}',
                    l10n.roomName(r.room),
                    l10n.placeName(r.place),
                    fitLabel(r.fit),
                  ],
              ],
              widths: const {
                0: pw.FixedColumnWidth(24),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(1.2),
              },
            ),

          heading(l10n.vastuReportZonesTitle),
          table(
            [
              l10n.vastuReportZoneColumn,
              l10n.vastuReportThemeColumn,
              l10n.vastuPlanStepRooms,
            ],
            zoneRows,
            widths: const {
              0: pw.FlexColumnWidth(1.6),
              1: pw.FlexColumnWidth(2.2),
              2: pw.FlexColumnWidth(2),
            },
          ),

          heading(l10n.vastuDoshasTitle),
          if (analysis.doshas.isEmpty)
            para(l10n.vastuDoshasNone)
          else
            for (final dosha in analysis.doshas)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(
                      color: dosha.severity == DoshaSeverity.major
                          ? _red
                          : _amber,
                      width: 3,
                    ),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${l10n.doshaTitle(dosha)}  ·  '
                      '${l10n.vastuSeverity(dosha.severity.name)}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (l10n.doshaDetail(dosha) case final detail?)
                      note(detail),
                    para(l10n.remedyFor(dosha)),
                    if (l10n.suggestionFor(dosha) case final move?)
                      para(move, color: _green),
                  ],
                ),
              ),

          heading(l10n.vastuGeneralUpayTitle),
          para(l10n.vastuGeneralUpay),

          pw.SizedBox(height: 18),
          pw.Divider(color: _rule),
          note(l10n.vastuReportDisclaimer),
        ],
      ),
    );

    return document.save();
  }

  static String _roomsIn(
    VastuAnalysis analysis,
    ZonePlace place,
    AppLocalizations l10n,
  ) {
    final rooms = [
      for (final r in analysis.rooms)
        if (r.place == place)
          '${l10n.roomName(r.room)} (${l10n.vastuFit(r.fit.name)})',
    ];
    return rooms.isEmpty ? '—' : rooms.join(', ');
  }

  /// The plan image with the house outline, 16-zone grid, Brahmasthan,
  /// north arrow, door and numbered room markers.
  pw.Widget _plan(
    VastuLayout layout,
    VastuAnalysis analysis,
    Uint8List? image,
    Map<String, int> markNumber,
  ) {
    const maxWidth = 460.0;
    const maxHeight = 420.0;
    var width = maxWidth;
    var height = width / layout.aspectRatio;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * layout.aspectRatio;
    }
    final f = layout.frame;
    final left = f.left * width;
    final top = f.top * height;
    final right = f.right * width;
    final bottom = f.bottom * height;
    final cx = (left + right) / 2;
    final cy = (top + bottom) / 2;

    // Point at image angle [deg] on the outline, in top-left coordinates.
    (double, double) edge(double deg) {
      final a = deg * math.pi / 180;
      final dx = math.sin(a);
      final dy = -math.cos(a);
      var t = double.infinity;
      if (dx > 1e-9) t = math.min(t, (right - cx) / dx);
      if (dx < -1e-9) t = math.min(t, (left - cx) / dx);
      if (dy > 1e-9) t = math.min(t, (bottom - cy) / dy);
      if (dy < -1e-9) t = math.min(t, (top - cy) / dy);
      if (!t.isFinite) t = 0;
      return (cx + dx * t, cy + dy * t);
    }

    final northEdge = edge(layout.imageAngleOf(0));
    final northTip = (
      cx + (northEdge.$1 - cx) * 0.55,
      cy + (northEdge.$2 - cy) * 0.55,
    );

    pw.Widget label(String text, double x, double y, PdfColor color) =>
        pw.Positioned(
          left: x - 14,
          top: y - 6,
          child: pw.Container(
            width: 28,
            alignment: pw.Alignment.center,
            color: PdfColors.white,
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ),
        );

    pw.Widget zoneLabel(VastuZone zone) {
      final (ex, ey) = edge(layout.imageAngleOf(zone.centre));
      return label(
        zone.abbreviation,
        cx + (ex - cx) * 0.8,
        cy + (ey - cy) * 0.8,
        zone == VastuZone.n ? _red : _accent,
      );
    }

    pw.Widget dot(double x, double y, String text, PdfColor color) =>
        pw.Positioned(
          left: x - 7,
          top: y - 7,
          child: pw.Container(
            width: 14,
            height: 14,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: color,
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: PdfColors.white, width: 1),
            ),
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.white),
            ),
          ),
        );

    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.Stack(
        children: [
          if (image != null)
            pw.Positioned.fill(
              child: pw.Image(pw.MemoryImage(image), fit: pw.BoxFit.fill),
            )
          else
            pw.Positioned.fill(
              child: pw.Container(color: const PdfColor.fromInt(0xFFF4EFE6)),
            ),
          pw.Positioned.fill(
            child: pw.CustomPaint(
              size: PdfPoint(width, height),
              painter: (canvas, size) {
                // PDF coordinates run bottom-up.
                double y(double top) => size.y - top;

                canvas
                  ..setStrokeColor(_accent)
                  ..setLineWidth(1.4)
                  ..drawRect(left, y(bottom), right - left, bottom - top)
                  ..strokePath();

                final bw = (right - left) / 3;
                final bh = (bottom - top) / 3;
                // Light tint over the Brahmasthan; the plan shows through.
                canvas
                  ..saveContext()
                  ..setGraphicState(const PdfGraphicState(fillOpacity: 0.12))
                  ..setFillColor(_accent)
                  ..drawRect(cx - bw / 2, y(cy + bh / 2), bw, bh)
                  ..fillPath()
                  ..restoreContext();
                canvas
                  ..setStrokeColor(_accent)
                  ..setLineWidth(0.6)
                  ..drawRect(cx - bw / 2, y(cy + bh / 2), bw, bh)
                  ..strokePath();

                canvas.setLineWidth(0.6);
                for (final zone in VastuZone.values) {
                  final (ex, ey) = edge(
                    layout.imageAngleOf(zone.startBearing),
                  );
                  canvas
                    ..moveTo(cx, y(cy))
                    ..lineTo(ex, y(ey));
                }
                canvas.strokePath();

                canvas
                  ..setStrokeColor(_red)
                  ..setLineWidth(1.8)
                  ..moveTo(cx, y(cy))
                  ..lineTo(northTip.$1, y(northTip.$2))
                  ..strokePath();
              },
            ),
          ),
          for (final zone in VastuZone.values) zoneLabel(zone),
          if (layout.entrance case final door?)
            dot(door.x * width, door.y * height, 'D', _accent),
          for (final r in analysis.rooms)
            dot(
              r.mark.at.x * width,
              r.mark.at.y * height,
              '${markNumber[r.mark.id]}',
              switch (r.fit) {
                ZoneFit.ideal => _green,
                ZoneFit.acceptable => _amber,
                ZoneFit.avoid => _red,
              },
            ),
        ],
      ),
    );
  }
}
