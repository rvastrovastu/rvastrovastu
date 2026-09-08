import 'vastu_entry_direction.dart';

enum VastuEntrySegment {
  n1(VastuEntryDirection.north, 1),
  n2(VastuEntryDirection.north, 2),
  n3(VastuEntryDirection.north, 3),
  n4(VastuEntryDirection.north, 4),
  n5(VastuEntryDirection.north, 5),
  n6(VastuEntryDirection.north, 6),
  n7(VastuEntryDirection.north, 7),
  n8(VastuEntryDirection.north, 8),

  e1(VastuEntryDirection.east, 1),
  e2(VastuEntryDirection.east, 2),
  e3(VastuEntryDirection.east, 3),
  e4(VastuEntryDirection.east, 4),
  e5(VastuEntryDirection.east, 5),
  e6(VastuEntryDirection.east, 6),
  e7(VastuEntryDirection.east, 7),
  e8(VastuEntryDirection.east, 8),

  s1(VastuEntryDirection.south, 1),
  s2(VastuEntryDirection.south, 2),
  s3(VastuEntryDirection.south, 3),
  s4(VastuEntryDirection.south, 4),
  s5(VastuEntryDirection.south, 5),
  s6(VastuEntryDirection.south, 6),
  s7(VastuEntryDirection.south, 7),
  s8(VastuEntryDirection.south, 8),

  w1(VastuEntryDirection.west, 1),
  w2(VastuEntryDirection.west, 2),
  w3(VastuEntryDirection.west, 3),
  w4(VastuEntryDirection.west, 4),
  w5(VastuEntryDirection.west, 5),
  w6(VastuEntryDirection.west, 6),
  w7(VastuEntryDirection.west, 7),
  w8(VastuEntryDirection.west, 8);

  const VastuEntrySegment(this.direction, this.number);

  final VastuEntryDirection direction;
  final int number;

  /// The traditional pada number within the wall segment.
  ///
  /// Current supported wall segmentation is 1–8 for each cardinal wall.
  int get pada => number;

  bool get isNorth => direction == VastuEntryDirection.north;

  bool get isEast => direction == VastuEntryDirection.east;

  bool get isSouth => direction == VastuEntryDirection.south;

  bool get isWest => direction == VastuEntryDirection.west;

  /// True when the segment belongs to a cardinal wall.
  ///
  /// Diagonal directions are intentionally retained in the direction enum
  /// for future use, but they are not currently valid wall segments.
  bool get isCardinal => isNorth || isEast || isSouth || isWest;

  String get code {
    final prefix = switch (direction) {
      VastuEntryDirection.north => 'N',
      VastuEntryDirection.northeast => 'NE',
      VastuEntryDirection.east => 'E',
      VastuEntryDirection.southeast => 'SE',
      VastuEntryDirection.south => 'S',
      VastuEntryDirection.southwest => 'SW',
      VastuEntryDirection.west => 'W',
      VastuEntryDirection.northwest => 'NW',
    };

    return '$prefix$number';
  }
}
