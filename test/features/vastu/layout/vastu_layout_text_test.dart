import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/vastu/layout/data/vastu_report_pdf_service.dart';
import 'package:rv_astro_vastu/features/vastu/layout/domain/vastu_analysis.dart';
import 'package:rv_astro_vastu/features/vastu/layout/domain/vastu_layout.dart';
import 'package:rv_astro_vastu/features/vastu/layout/presentation/vastu_layout_text.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

VastuLayout _layout({
  List<RoomMark> rooms = const [],
  Set<VastuCorner> cuts = const {},
  PlanPoint? entrance,
}) => VastuLayout(
  id: 'h1',
  name: 'Sunrise Villa',
  updatedAt: DateTime(2026, 10, 20),
  frame: const PlanFrame(left: 0, top: 0, right: 1, bottom: 1),
  entrance: entrance,
  rooms: rooms,
  cutCorners: cuts,
);

RoomMark _mark(VastuRoom room, double x, double y) =>
    RoomMark(id: '${room.name}$x$y', room: room, at: PlanPoint(x, y));

/// A home with one of each kind of dosha.
VastuLayout _troubled() => _layout(
  entrance: const PlanPoint(0.05, 0), // N1, inauspicious
  rooms: [
    _mark(VastuRoom.toilet, 0.9, 0.1), // NE: major
    _mark(VastuRoom.kitchen, 0.5, 0.05), // N: avoid
    _mark(VastuRoom.masterBedroom, 0.1, 0.9), // SW: ideal
    _mark(VastuRoom.store, 0.5, 0.5), // centre: avoid
  ],
  cuts: {VastuCorner.ne, VastuCorner.nw},
);

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('text', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('every room, corner and wall has its own remedy and name', () {
      for (final room in VastuRoom.values) {
        expect(l10n.roomName(room), isNot(room.name), reason: room.name);
        expect(
          l10n.vastuRemedyRoom(room.name),
          isNot(room.name),
          reason: room.name,
        );
      }
      for (final corner in VastuCorner.values) {
        expect(l10n.vastuRemedyCorner(corner.name), isNot(corner.name));
        expect(l10n.vastuCornerName(corner.name), isNot(corner.name));
      }
      for (final wall in ['n', 'e', 's', 'w']) {
        expect(l10n.vastuRemedyEntrance(wall), isNot(wall));
      }
    });

    test('doshas read as sentences with remedies and suggestions', () {
      final analysis = VastuAnalysis.of(_troubled());
      final kinds = analysis.doshas.map((d) => d.kind).toSet();
      expect(kinds, {DoshaKind.entrance, DoshaKind.room, DoshaKind.cutCorner});

      for (final dosha in analysis.doshas) {
        expect(l10n.doshaTitle(dosha), isNotEmpty);
        expect(l10n.remedyFor(dosha).length, greaterThan(40));
        if (dosha.kind == DoshaKind.room) {
          expect(l10n.suggestionFor(dosha), startsWith('Better zones:'));
        } else {
          expect(l10n.suggestionFor(dosha), isNull);
        }
      }

      final toilet = analysis.doshas.firstWhere(
        (d) => d.room?.room == VastuRoom.toilet,
      );
      expect(l10n.doshaTitle(toilet), 'Toilet in Northeast');
      expect(l10n.remedyFor(toilet), contains('sea salt'));

      final store = analysis.doshas.firstWhere(
        (d) => d.room?.room == VastuRoom.store,
      );
      expect(l10n.doshaTitle(store), 'Store room in Brahmasthan (centre)');
      expect(l10n.doshaDetail(store), l10n.vastuDoshaCentre);
    });

    test('facing label names the direction', () {
      expect(l10n.facingLabel(2), 'Main door faces 2° · North');
      expect(l10n.facingLabel(91), 'Main door faces 91° · East');
    });
  });

  group('report PDF', () {
    for (final code in ['en', 'hi', 'mr']) {
      test('builds a $code report with the plan image', () async {
        final bytes = await const VastuReportPdfService().build(
          layout: _troubled().copyWith(aspectRatio: 1.4),
          l10n: lookupAppLocalizations(Locale(code)),
          planImage: _png,
          generatedAt: DateTime(2026, 10, 20),
        );
        expect(bytes.length, greaterThan(5000));
        expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      });
    }

    test('builds without an image or any rooms', () async {
      final bytes = await const VastuReportPdfService().build(
        layout: _layout(),
        l10n: lookupAppLocalizations(const Locale('en')),
      );
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
