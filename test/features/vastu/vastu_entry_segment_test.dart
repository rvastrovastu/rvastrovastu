import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_direction.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_segment.dart';

void main() {
  group('VastuEntrySegment', () {
    test('W4 exposes correct geometry', () {
      const segment = VastuEntrySegment.w4;

      expect(segment.direction, VastuEntryDirection.west);
      expect(segment.number, 4);
      expect(segment.pada, 4);
      expect(segment.code, 'W4');

      expect(segment.isWest, isTrue);
      expect(segment.isNorth, isFalse);
      expect(segment.isEast, isFalse);
      expect(segment.isSouth, isFalse);
      expect(segment.isCardinal, isTrue);
    });

    test('W5 exposes correct geometry', () {
      const segment = VastuEntrySegment.w5;

      expect(segment.direction, VastuEntryDirection.west);
      expect(segment.number, 5);
      expect(segment.pada, 5);
      expect(segment.code, 'W5');

      expect(segment.isWest, isTrue);
      expect(segment.isCardinal, isTrue);
    });

    test('all cardinal wall segments have valid pada numbers', () {
      final segments = <VastuEntrySegment>[
        ...VastuEntrySegment.values.where((segment) => segment.isCardinal),
      ];

      expect(segments, hasLength(32));

      for (final segment in segments) {
        expect(segment.pada, inInclusiveRange(1, 8));
        expect(segment.code, matches(r'^[NESW][1-8]$'));
        expect(segment.isCardinal, isTrue);
      }
    });

    test('each cardinal wall contains exactly eight padas', () {
      for (final direction in <VastuEntryDirection>[
        VastuEntryDirection.north,
        VastuEntryDirection.east,
        VastuEntryDirection.south,
        VastuEntryDirection.west,
      ]) {
        final segments = VastuEntrySegment.values
            .where((segment) => segment.direction == direction)
            .toList();

        expect(segments, hasLength(8));
        expect(
          segments.map((segment) => segment.pada).toList(),
          orderedEquals(<int>[1, 2, 3, 4, 5, 6, 7, 8]),
        );
      }
    });

    test('diagonal directions are not represented as wall segments', () {
      final diagonalDirections = <VastuEntryDirection>{
        VastuEntryDirection.northeast,
        VastuEntryDirection.southeast,
        VastuEntryDirection.southwest,
        VastuEntryDirection.northwest,
      };

      final diagonalSegments = VastuEntrySegment.values.where(
        (segment) => diagonalDirections.contains(segment.direction),
      );

      expect(diagonalSegments, isEmpty);
    });
  });
}
