import '../../domain/entities/vastu_entry_assessment.dart';
import '../../domain/entities/vastu_entry_segment.dart';
import '../../domain/entities/vastu_zone.dart';
import 'vastu_layout.dart';

/// How well a room suits the zone it sits in.
enum ZoneFit { ideal, acceptable, avoid }

enum DoshaSeverity { major, minor }

/// Traditional placement rules: best zones and zones to avoid for each
/// room. Every other zone is acceptable. 'centre' is the Brahmasthan.
class VastuRule {
  final Set<String> ideal;
  final Set<String> avoid;

  const VastuRule({required this.ideal, required this.avoid});
}

const Map<VastuRoom, VastuRule> vastuRules = {
  VastuRoom.kitchen: VastuRule(
    ideal: {'se', 'ese', 'sse'},
    avoid: {'n', 'nne', 'ne', 'ene', 'sw', 'ssw', 'centre'},
  ),
  VastuRoom.masterBedroom: VastuRule(
    ideal: {'sw', 's', 'wsw'},
    avoid: {'ne', 'nne', 'ene', 'se', 'centre'},
  ),
  VastuRoom.bedroom: VastuRule(
    ideal: {'s', 'w', 'sw', 'wsw', 'nw'},
    avoid: {'ne', 'se', 'centre'},
  ),
  VastuRoom.childrenRoom: VastuRule(
    ideal: {'w', 'wnw', 'nw', 'e'},
    avoid: {'se', 'ssw', 'centre'},
  ),
  VastuRoom.guestRoom: VastuRule(
    ideal: {'nw', 'wnw', 'nnw'},
    avoid: {'sw', 'ne', 'centre'},
  ),
  VastuRoom.living: VastuRule(
    ideal: {'n', 'nne', 'ne', 'e', 'nw'},
    avoid: {'sw', 'ssw'},
  ),
  VastuRoom.dining: VastuRule(
    ideal: {'w', 'wnw', 'e'},
    avoid: {'ssw', 'sw'},
  ),
  VastuRoom.pooja: VastuRule(
    ideal: {'ne', 'nne', 'ene', 'n', 'e'},
    avoid: {'s', 'sse', 'ssw', 'sw', 'se'},
  ),
  VastuRoom.study: VastuRule(
    ideal: {'e', 'ne', 'n', 'wsw'},
    avoid: {'sse', 'sw'},
  ),
  VastuRoom.office: VastuRule(
    ideal: {'n', 'e', 'w', 'ne'},
    avoid: {'ssw', 'sse'},
  ),
  VastuRoom.toilet: VastuRule(
    ideal: {'wnw', 'ssw', 'ese'},
    avoid: {'ne', 'nne', 'ene', 'n', 'e', 'sw', 'centre'},
  ),
  VastuRoom.bathroom: VastuRule(
    ideal: {'e', 'n', 'wnw', 'ese'},
    avoid: {'sw', 'se', 'centre'},
  ),
  VastuRoom.store: VastuRule(
    ideal: {'sw', 's', 'w', 'nw'},
    avoid: {'ne', 'centre'},
  ),
  VastuRoom.staircase: VastuRule(
    ideal: {'s', 'sw', 'w', 'ssw', 'wsw'},
    avoid: {'ne', 'n', 'e', 'centre'},
  ),
  VastuRoom.undergroundWater: VastuRule(
    ideal: {'n', 'nne', 'ne', 'e'},
    avoid: {'se', 's', 'ssw', 'sw', 'centre'},
  ),
  VastuRoom.overheadTank: VastuRule(
    ideal: {'sw', 'w', 's', 'wsw'},
    avoid: {'ne', 'se', 'centre'},
  ),
  VastuRoom.septicTank: VastuRule(
    ideal: {'wnw', 'nnw', 'ssw'},
    avoid: {'ne', 'n', 'e', 'sw', 'centre'},
  ),
  VastuRoom.parking: VastuRule(
    ideal: {'nw', 'se'},
    avoid: {'ne', 'sw', 'centre'},
  ),
  VastuRoom.cashLocker: VastuRule(
    ideal: {'n', 'sw'},
    avoid: {'se', 'sse', 'ene'},
  ),
  VastuRoom.openSpace: VastuRule(
    ideal: {'n', 'ne', 'e', 'centre'},
    avoid: {'sw', 's'},
  ),
};

/// Rooms whose misplacement is serious in the most sensitive zones.
const _heavyRooms = {
  VastuRoom.toilet,
  VastuRoom.septicTank,
  VastuRoom.kitchen,
  VastuRoom.staircase,
};
const _sensitiveZones = {'ne', 'centre', 'sw'};

ZoneFit fitOf(VastuRoom room, ZonePlace place) {
  final rule = vastuRules[room]!;
  if (rule.ideal.contains(place.key)) return ZoneFit.ideal;
  if (rule.avoid.contains(place.key)) return ZoneFit.avoid;
  return ZoneFit.acceptable;
}

DoshaSeverity _severityOf(VastuRoom room, ZonePlace place) {
  final major =
      (_heavyRooms.contains(room) && _sensitiveZones.contains(place.key)) ||
      (room == VastuRoom.masterBedroom && {'ne', 'se'}.contains(place.key)) ||
      (room == VastuRoom.undergroundWater &&
          {'sw', 'se'}.contains(place.key)) ||
      (room == VastuRoom.overheadTank && place.key == 'ne');
  return major ? DoshaSeverity.major : DoshaSeverity.minor;
}

/// Traditional reading of each of the 32 entrance padas.
const Map<VastuEntrySegment, VastuAssessmentLevel> padaLevels = {
  VastuEntrySegment.e1: VastuAssessmentLevel.challenging,
  VastuEntrySegment.e2: VastuAssessmentLevel.challenging,
  VastuEntrySegment.e3: VastuAssessmentLevel.favorable,
  VastuEntrySegment.e4: VastuAssessmentLevel.favorable,
  VastuEntrySegment.e5: VastuAssessmentLevel.challenging,
  VastuEntrySegment.e6: VastuAssessmentLevel.neutral,
  VastuEntrySegment.e7: VastuAssessmentLevel.challenging,
  VastuEntrySegment.e8: VastuAssessmentLevel.challenging,
  VastuEntrySegment.s1: VastuAssessmentLevel.challenging,
  VastuEntrySegment.s2: VastuAssessmentLevel.challenging,
  VastuEntrySegment.s3: VastuAssessmentLevel.favorable,
  VastuEntrySegment.s4: VastuAssessmentLevel.favorable,
  VastuEntrySegment.s5: VastuAssessmentLevel.challenging,
  VastuEntrySegment.s6: VastuAssessmentLevel.challenging,
  VastuEntrySegment.s7: VastuAssessmentLevel.challenging,
  VastuEntrySegment.s8: VastuAssessmentLevel.challenging,
  VastuEntrySegment.w1: VastuAssessmentLevel.challenging,
  VastuEntrySegment.w2: VastuAssessmentLevel.challenging,
  VastuEntrySegment.w3: VastuAssessmentLevel.favorable,
  VastuEntrySegment.w4: VastuAssessmentLevel.favorable,
  VastuEntrySegment.w5: VastuAssessmentLevel.favorable,
  VastuEntrySegment.w6: VastuAssessmentLevel.challenging,
  VastuEntrySegment.w7: VastuAssessmentLevel.challenging,
  VastuEntrySegment.w8: VastuAssessmentLevel.challenging,
  VastuEntrySegment.n1: VastuAssessmentLevel.challenging,
  VastuEntrySegment.n2: VastuAssessmentLevel.challenging,
  VastuEntrySegment.n3: VastuAssessmentLevel.favorable,
  VastuEntrySegment.n4: VastuAssessmentLevel.favorable,
  VastuEntrySegment.n5: VastuAssessmentLevel.favorable,
  VastuEntrySegment.n6: VastuAssessmentLevel.challenging,
  VastuEntrySegment.n7: VastuAssessmentLevel.neutral,
  VastuEntrySegment.n8: VastuAssessmentLevel.neutral,
};

/// One room as the analysis sees it.
class RoomFinding {
  final RoomMark mark;
  final ZonePlace place;
  final ZoneFit fit;

  const RoomFinding({
    required this.mark,
    required this.place,
    required this.fit,
  });

  VastuRoom get room => mark.room;
}

/// Kinds of dosha the analysis can report.
enum DoshaKind { entrance, room, cutCorner }

class VastuDosha {
  final DoshaKind kind;
  final DoshaSeverity severity;

  /// Set for [DoshaKind.room].
  final RoomFinding? room;

  /// Set for [DoshaKind.entrance].
  final VastuEntrySegment? pada;

  /// Set for [DoshaKind.cutCorner].
  final VastuCorner? corner;

  const VastuDosha._({
    required this.kind,
    required this.severity,
    this.room,
    this.pada,
    this.corner,
  });
}

enum VastuScoreBand { excellent, good, average, attention }

class VastuAnalysis {
  final VastuLayout layout;
  final VastuEntrySegment entrancePada;
  final VastuAssessmentLevel entranceLevel;
  final List<RoomFinding> rooms;
  final List<VastuDosha> doshas;

  /// 0–100.
  final int score;

  const VastuAnalysis._({
    required this.layout,
    required this.entrancePada,
    required this.entranceLevel,
    required this.rooms,
    required this.doshas,
    required this.score,
  });

  VastuScoreBand get band => score >= 80
      ? VastuScoreBand.excellent
      : score >= 65
      ? VastuScoreBand.good
      : score >= 45
      ? VastuScoreBand.average
      : VastuScoreBand.attention;

  int get majorCount =>
      doshas.where((d) => d.severity == DoshaSeverity.major).length;

  /// Rooms grouped by the place they fall in.
  Map<ZonePlace, List<RoomFinding>> get byPlace {
    final map = <ZonePlace, List<RoomFinding>>{};
    for (final r in rooms) {
      map.putIfAbsent(r.place, () => []).add(r);
    }
    return map;
  }

  static const _roomWeights = {
    VastuRoom.kitchen: 3.0,
    VastuRoom.masterBedroom: 3.0,
    VastuRoom.toilet: 3.0,
    VastuRoom.pooja: 2.0,
    VastuRoom.septicTank: 2.0,
    VastuRoom.staircase: 2.0,
    VastuRoom.undergroundWater: 2.0,
    VastuRoom.overheadTank: 1.5,
    VastuRoom.cashLocker: 1.5,
  };

  factory VastuAnalysis.of(VastuLayout layout) {
    final pada = layout.entrancePada;
    final level = padaLevels[pada]!;

    final rooms = [
      for (final mark in layout.rooms)
        if (layout.frame.contains(mark.at))
          RoomFinding(
            mark: mark,
            place: layout.placeOf(mark.at),
            fit: fitOf(mark.room, layout.placeOf(mark.at)),
          ),
    ];

    final found = <VastuDosha>[
      if (level == VastuAssessmentLevel.challenging)
        VastuDosha._(
          kind: DoshaKind.entrance,
          severity: DoshaSeverity.major,
          pada: pada,
        ),
      for (final r in rooms)
        if (r.fit == ZoneFit.avoid)
          VastuDosha._(
            kind: DoshaKind.room,
            severity: _severityOf(r.room, r.place),
            room: r,
          ),
      for (final corner in VastuCorner.values)
        if (layout.cutCorners.contains(corner))
          VastuDosha._(
            kind: DoshaKind.cutCorner,
            severity: corner == VastuCorner.ne || corner == VastuCorner.sw
                ? DoshaSeverity.major
                : DoshaSeverity.minor,
            corner: corner,
          ),
    ];
    // Majors first, keeping the order found within each group.
    final doshas = [
      for (final severity in DoshaSeverity.values)
        ...found.where((d) => d.severity == severity),
    ];

    var total = 0.0;
    var weight = 0.0;
    const entranceWeight = 3.0;
    total +=
        entranceWeight *
        switch (level) {
          VastuAssessmentLevel.favorable => 100,
          VastuAssessmentLevel.neutral => 65,
          VastuAssessmentLevel.challenging => 25,
        };
    weight += entranceWeight;
    for (final r in rooms) {
      final w = _roomWeights[r.room] ?? 1.0;
      total +=
          w *
          switch (r.fit) {
            ZoneFit.ideal => 100,
            ZoneFit.acceptable => 70,
            ZoneFit.avoid => r.severityPenalty,
          };
      weight += w;
    }
    var score = total / weight;
    for (final corner in layout.cutCorners) {
      score -= corner == VastuCorner.ne || corner == VastuCorner.sw ? 12 : 6;
    }

    return VastuAnalysis._(
      layout: layout,
      entrancePada: pada,
      entranceLevel: level,
      rooms: rooms,
      doshas: doshas,
      score: score.round().clamp(0, 100),
    );
  }
}

extension on RoomFinding {
  double get severityPenalty =>
      _severityOf(room, place) == DoshaSeverity.major ? 0 : 25;
}

/// The best zones for [room], in compass order.
List<String> idealZonesFor(VastuRoom room) {
  final ideal = vastuRules[room]!.ideal;
  return [
    for (final z in VastuZone.values)
      if (ideal.contains(z.name)) z.name,
    if (ideal.contains('centre')) 'centre',
  ];
}

/// Corner zone for a cut corner.
VastuZone zoneOfCorner(VastuCorner corner) => switch (corner) {
  VastuCorner.ne => VastuZone.ne,
  VastuCorner.se => VastuZone.se,
  VastuCorner.sw => VastuZone.sw,
  VastuCorner.nw => VastuZone.nw,
};
