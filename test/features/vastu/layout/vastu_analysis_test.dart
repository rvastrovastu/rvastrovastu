import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_assessment.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_segment.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_zone.dart';
import 'package:rv_astro_vastu/features/vastu/layout/domain/vastu_analysis.dart';
import 'package:rv_astro_vastu/features/vastu/layout/domain/vastu_layout.dart';

VastuLayout _layout({
  double facing = 0,
  PlanSide side = PlanSide.top,
  PlanPoint? entrance,
  List<RoomMark> rooms = const [],
  Set<VastuCorner> cuts = const {},
}) => VastuLayout(
  id: 'h1',
  name: 'Home',
  updatedAt: DateTime(2026, 10, 20),
  frame: const PlanFrame(left: 0, top: 0, right: 1, bottom: 1),
  entranceFacing: facing,
  doorSide: side,
  entrance: entrance,
  rooms: rooms,
  cutCorners: cuts,
);

RoomMark _mark(VastuRoom room, double x, double y) =>
    RoomMark(id: '$room$x$y', room: room, at: PlanPoint(x, y));

void main() {
  group('padaForBearing', () {
    test('runs clockwise from the north-east corner', () {
      expect(padaForBearing(45), VastuEntrySegment.e1);
      expect(padaForBearing(90), VastuEntrySegment.e5);
      expect(padaForBearing(134.9), VastuEntrySegment.e8);
      expect(padaForBearing(135), VastuEntrySegment.s1);
      expect(padaForBearing(225), VastuEntrySegment.w1);
      expect(padaForBearing(270), VastuEntrySegment.w5);
      expect(padaForBearing(315), VastuEntrySegment.n1);
      expect(padaForBearing(355), VastuEntrySegment.n4);
      expect(padaForBearing(5), VastuEntrySegment.n5);
      expect(padaForBearing(44.9), VastuEntrySegment.n8);
      expect(padaForBearing(-10), VastuEntrySegment.n4);
    });
  });

  group('orientation', () {
    test('door on the top side facing north keeps image-up as north', () {
      final layout = _layout();
      expect(layout.imageUpBearing, 0);
      expect(layout.bearingOf(const PlanPoint(1, 0.5)), closeTo(90, 1e-9));
      expect(layout.bearingOf(const PlanPoint(0.5, 1)), closeTo(180, 1e-9));
    });

    test('door on the right side facing east also means north is up', () {
      final layout = _layout(facing: 90, side: PlanSide.right);
      expect(layout.imageUpBearing, 0);
    });

    test('door on the bottom facing north turns the plan upside down', () {
      final layout = _layout(side: PlanSide.bottom);
      expect(layout.imageUpBearing, 180);
      expect(layout.bearingOf(const PlanPoint(0.5, 1)), closeTo(0, 1e-9));
      expect(layout.placeOf(const PlanPoint(0.5, 0.95)).zone, VastuZone.n);
    });

    test('aspect ratio is used for angles', () {
      final wide = VastuLayout(
        id: 'w',
        name: 'Wide',
        updatedAt: DateTime(2026),
        aspectRatio: 2,
        frame: const PlanFrame(left: 0, top: 0, right: 1, bottom: 1),
      );
      // Top-right corner of a 2:1 image is at atan(2/1) ≈ 63.4°.
      expect(wide.bearingOf(const PlanPoint(1, 0)), closeTo(63.43, 0.01));
    });

    test('the central ninth is the Brahmasthan', () {
      final layout = _layout();
      expect(layout.placeOf(const PlanPoint(0.5, 0.5)).isCentre, isTrue);
      expect(layout.placeOf(const PlanPoint(0.6, 0.4)).isCentre, isTrue);
      expect(layout.placeOf(const PlanPoint(0.9, 0.1)).zone, VastuZone.ne);
    });

    test('a tapped door decides the pada', () {
      // Door at the top, slightly right of centre: N5–N6 area.
      final layout = _layout(entrance: const PlanPoint(0.55, 0));
      expect(layout.entrancePada, VastuEntrySegment.n5);
    });
  });

  group('analysis', () {
    test('a well-placed home scores high with no doshas', () {
      final analysis = VastuAnalysis.of(
        _layout(
          entrance: const PlanPoint(0.55, 0),
          rooms: [
            _mark(VastuRoom.kitchen, 0.9, 0.9), // SE
            _mark(VastuRoom.masterBedroom, 0.1, 0.9), // SW
            _mark(VastuRoom.pooja, 0.9, 0.1), // NE
          ],
        ),
      );
      expect(analysis.entranceLevel, VastuAssessmentLevel.favorable);
      expect(analysis.doshas, isEmpty);
      expect(analysis.score, 100);
      expect(analysis.band, VastuScoreBand.excellent);
    });

    test('a toilet in the north-east is a major dosha', () {
      final analysis = VastuAnalysis.of(
        _layout(
          entrance: const PlanPoint(0.55, 0),
          rooms: [_mark(VastuRoom.toilet, 0.9, 0.1)],
        ),
      );
      expect(analysis.doshas, hasLength(1));
      final dosha = analysis.doshas.single;
      expect(dosha.kind, DoshaKind.room);
      expect(dosha.severity, DoshaSeverity.major);
      expect(dosha.room!.place.zone, VastuZone.ne);
      expect(analysis.score, lessThan(65));
    });

    test('a bad entrance and cut corners are reported, majors first', () {
      final analysis = VastuAnalysis.of(
        _layout(
          entrance: const PlanPoint(0.05, 0), // N1 area
          cuts: {VastuCorner.nw, VastuCorner.ne},
        ),
      );
      expect(analysis.entrancePada, VastuEntrySegment.n1);
      expect(analysis.doshas.map((d) => d.kind), [
        DoshaKind.entrance,
        DoshaKind.cutCorner,
        DoshaKind.cutCorner,
      ]);
      expect(analysis.doshas.last.severity, DoshaSeverity.minor);
      expect(analysis.majorCount, 2);
    });

    test('rooms outside the frame are ignored', () {
      final layout = VastuLayout(
        id: 'x',
        name: 'x',
        updatedAt: DateTime(2026),
        frame: const PlanFrame(left: 0.2, top: 0.2, right: 0.8, bottom: 0.8),
        rooms: [_mark(VastuRoom.toilet, 0.05, 0.05)],
      );
      expect(VastuAnalysis.of(layout).rooms, isEmpty);
    });

    test('every room has rules and ideal zones', () {
      for (final room in VastuRoom.values) {
        expect(vastuRules[room], isNotNull, reason: room.name);
        expect(idealZonesFor(room), isNotEmpty, reason: room.name);
      }
      expect(padaLevels.length, 32);
    });
  });

  test('layouts survive a JSON round trip', () {
    final layout = _layout(
      facing: 72.5,
      side: PlanSide.left,
      entrance: const PlanPoint(0.1, 0.4),
      rooms: [_mark(VastuRoom.kitchen, 0.8, 0.8)],
      cuts: {VastuCorner.sw},
    ).copyWith(imageFile: 'h1.jpg', aspectRatio: 1.5);

    final back = VastuLayout.fromJson(layout.toJson())!;
    expect(back.name, 'Home');
    expect(back.imageFile, 'h1.jpg');
    expect(back.aspectRatio, 1.5);
    expect(back.entranceFacing, 72.5);
    expect(back.doorSide, PlanSide.left);
    expect(back.entrance, const PlanPoint(0.1, 0.4));
    expect(back.rooms.single.room, VastuRoom.kitchen);
    expect(back.cutCorners, {VastuCorner.sw});
    expect(VastuLayout.fromJson({'bad': 1}), isNull);
  });
}
