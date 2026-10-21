import 'dart:math' as math;

import '../../domain/entities/vastu_entry_segment.dart';
import '../../domain/entities/vastu_zone.dart';

/// Rooms and fixtures a user can tag on a floor plan.
enum VastuRoom {
  kitchen,
  masterBedroom,
  bedroom,
  childrenRoom,
  guestRoom,
  living,
  dining,
  pooja,
  study,
  office,
  toilet,
  bathroom,
  store,
  staircase,
  undergroundWater,
  overheadTank,
  septicTank,
  parking,
  cashLocker,
  openSpace,
}

/// Sides of the plan image, clockwise from the top.
enum PlanSide {
  top(0),
  right(90),
  bottom(180),
  left(270);

  /// Angle of this side's outward direction, clockwise from image-up.
  final double angle;

  const PlanSide(this.angle);
}

/// The four corners whose absence (a cut) matters most in Vastu.
enum VastuCorner { ne, se, sw, nw }

/// A point on the plan, as fractions of the image width and height
/// (0,0 is the top-left corner).
class PlanPoint {
  final double x;
  final double y;

  const PlanPoint(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory PlanPoint.fromJson(Map<String, dynamic> json) =>
      PlanPoint((json['x'] as num).toDouble(), (json['y'] as num).toDouble());

  @override
  bool operator ==(Object other) =>
      other is PlanPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// The house outline on the plan, as fractions of the image size.
class PlanFrame {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const PlanFrame({
    this.left = 0.1,
    this.top = 0.1,
    this.right = 0.9,
    this.bottom = 0.9,
  });

  double get width => right - left;
  double get height => bottom - top;
  PlanPoint get centre => PlanPoint((left + right) / 2, (top + bottom) / 2);

  bool contains(PlanPoint p) =>
      p.x >= left && p.x <= right && p.y >= top && p.y <= bottom;

  /// True inside the central ninth of the frame: the Brahmasthan.
  bool isBrahmasthan(PlanPoint p) =>
      (p.x - centre.x).abs() <= width / 6 &&
      (p.y - centre.y).abs() <= height / 6;

  PlanFrame copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) => PlanFrame(
    left: left ?? this.left,
    top: top ?? this.top,
    right: right ?? this.right,
    bottom: bottom ?? this.bottom,
  );

  Map<String, dynamic> toJson() => {
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };

  factory PlanFrame.fromJson(Map<String, dynamic> json) => PlanFrame(
    left: (json['left'] as num).toDouble(),
    top: (json['top'] as num).toDouble(),
    right: (json['right'] as num).toDouble(),
    bottom: (json['bottom'] as num).toDouble(),
  );
}

/// One tagged room on the plan.
class RoomMark {
  final String id;
  final VastuRoom room;
  final PlanPoint at;

  const RoomMark({required this.id, required this.room, required this.at});

  Map<String, dynamic> toJson() => {
    'id': id,
    'room': room.name,
    'at': at.toJson(),
  };

  static RoomMark? fromJson(Map<String, dynamic> json) {
    final room = VastuRoom.values.asNameMap()[json['room']];
    if (room == null) return null;
    return RoomMark(
      id: json['id'] as String,
      room: room,
      at: PlanPoint.fromJson(Map<String, dynamic>.from(json['at'] as Map)),
    );
  }
}

/// Where a point falls: one of the 16 zones, or the centre.
class ZonePlace {
  /// Null for the Brahmasthan (centre).
  final VastuZone? zone;

  const ZonePlace(this.zone);

  bool get isCentre => zone == null;

  /// 'n', 'nne', … or 'centre'.
  String get key => zone?.name ?? 'centre';

  @override
  bool operator ==(Object other) => other is ZonePlace && other.zone == zone;

  @override
  int get hashCode => zone.hashCode;
}

/// A saved house plan with everything needed for the analysis.
class VastuLayout {
  final String id;
  final String name;

  /// File name of the plan image inside the app's Vastu folder, if any.
  final String? imageFile;

  /// Image width divided by height (1 when there is no image).
  final double aspectRatio;
  final PlanFrame frame;

  /// Compass degree the main door faces, read from inside looking out.
  final double entranceFacing;

  /// Which side of the plan image the main door is on.
  final PlanSide doorSide;

  /// The main door's position on the plan, when the user tapped it.
  final PlanPoint? entrance;
  final List<RoomMark> rooms;
  final Set<VastuCorner> cutCorners;
  final DateTime updatedAt;

  const VastuLayout({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.imageFile,
    this.aspectRatio = 1,
    this.frame = const PlanFrame(),
    this.entranceFacing = 0,
    this.doorSide = PlanSide.top,
    this.entrance,
    this.rooms = const [],
    this.cutCorners = const {},
  });

  /// Compass bearing of "up" on the plan image.
  double get imageUpBearing => _wrap(entranceFacing - doorSide.angle);

  /// Compass bearing of [p] seen from the centre of the house.
  double bearingOf(PlanPoint p) {
    final c = frame.centre;
    final dx = (p.x - c.x) * aspectRatio;
    final dy = p.y - c.y;
    if (dx == 0 && dy == 0) return imageUpBearing;
    final fromUp = math.atan2(dx, -dy) * 180 / math.pi;
    return _wrap(imageUpBearing + fromUp);
  }

  /// Image angle (clockwise from up) at which compass [bearing] lies.
  double imageAngleOf(double bearing) => _wrap(bearing - imageUpBearing);

  ZonePlace placeOf(PlanPoint p) => frame.isBrahmasthan(p)
      ? const ZonePlace(null)
      : ZonePlace(vastuZoneForHeading(bearingOf(p)));

  /// Bearing used for the entrance pada: the tapped door, else the facing.
  double get entranceBearing =>
      entrance == null ? _wrap(entranceFacing) : bearingOf(entrance!);

  VastuEntrySegment get entrancePada => padaForBearing(entranceBearing);

  VastuLayout copyWith({
    String? name,
    String? imageFile,
    bool clearImage = false,
    double? aspectRatio,
    PlanFrame? frame,
    double? entranceFacing,
    PlanSide? doorSide,
    PlanPoint? entrance,
    bool clearEntrance = false,
    List<RoomMark>? rooms,
    Set<VastuCorner>? cutCorners,
    DateTime? updatedAt,
  }) => VastuLayout(
    id: id,
    name: name ?? this.name,
    imageFile: clearImage ? null : imageFile ?? this.imageFile,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    frame: frame ?? this.frame,
    entranceFacing: entranceFacing ?? this.entranceFacing,
    doorSide: doorSide ?? this.doorSide,
    entrance: clearEntrance ? null : entrance ?? this.entrance,
    rooms: rooms ?? this.rooms,
    cutCorners: cutCorners ?? this.cutCorners,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageFile': imageFile,
    'aspectRatio': aspectRatio,
    'frame': frame.toJson(),
    'entranceFacing': entranceFacing,
    'doorSide': doorSide.name,
    'entrance': entrance?.toJson(),
    'rooms': [for (final r in rooms) r.toJson()],
    'cutCorners': [for (final c in cutCorners) c.name],
    'updatedAt': updatedAt.toIso8601String(),
  };

  static VastuLayout? fromJson(Map<String, dynamic> json) {
    try {
      return VastuLayout(
        id: json['id'] as String,
        name: json['name'] as String,
        imageFile: json['imageFile'] as String?,
        aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 1,
        frame: json['frame'] == null
            ? const PlanFrame()
            : PlanFrame.fromJson(Map<String, dynamic>.from(json['frame'])),
        entranceFacing: (json['entranceFacing'] as num?)?.toDouble() ?? 0,
        doorSide:
            PlanSide.values.asNameMap()[json['doorSide']] ?? PlanSide.top,
        entrance: json['entrance'] == null
            ? null
            : PlanPoint.fromJson(Map<String, dynamic>.from(json['entrance'])),
        rooms: [
          for (final r in (json['rooms'] as List? ?? const []))
            ?RoomMark.fromJson(Map<String, dynamic>.from(r as Map)),
        ],
        cutCorners: {
          for (final c in (json['cutCorners'] as List? ?? const []))
            ?VastuCorner.values.asNameMap()[c],
        },
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}

double _wrap(double degrees) => ((degrees % 360) + 360) % 360;

/// The 32 entrance padas run clockwise from the north-east corner:
/// E1–E8, S1–S8, W1–W8, N1–N8, each 11.25° wide.
VastuEntrySegment padaForBearing(double bearing) {
  const order = [
    VastuEntrySegment.e1, VastuEntrySegment.e2, VastuEntrySegment.e3, //
    VastuEntrySegment.e4, VastuEntrySegment.e5, VastuEntrySegment.e6,
    VastuEntrySegment.e7, VastuEntrySegment.e8,
    VastuEntrySegment.s1, VastuEntrySegment.s2, VastuEntrySegment.s3,
    VastuEntrySegment.s4, VastuEntrySegment.s5, VastuEntrySegment.s6,
    VastuEntrySegment.s7, VastuEntrySegment.s8,
    VastuEntrySegment.w1, VastuEntrySegment.w2, VastuEntrySegment.w3,
    VastuEntrySegment.w4, VastuEntrySegment.w5, VastuEntrySegment.w6,
    VastuEntrySegment.w7, VastuEntrySegment.w8,
    VastuEntrySegment.n1, VastuEntrySegment.n2, VastuEntrySegment.n3,
    VastuEntrySegment.n4, VastuEntrySegment.n5, VastuEntrySegment.n6,
    VastuEntrySegment.n7, VastuEntrySegment.n8,
  ];
  final index = (_wrap(bearing - 45) / 11.25).floor() % 32;
  return order[index];
}
