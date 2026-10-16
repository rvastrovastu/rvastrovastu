import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/vastu/data/repositories/local_vastu_entry_deity_repository.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_segment.dart';

void main() {
  const repository = LocalVastuEntryDeityRepository();

  group('LocalVastuEntryDeityRepository', () {
    const expectedDeities = <VastuEntrySegment, String>{
      // NORTH
      VastuEntrySegment.n1: 'vastuRoga',
      VastuEntrySegment.n2: 'vastuNaga',
      VastuEntrySegment.n3: 'vastuMukhya',
      VastuEntrySegment.n4: 'vastuBhallata',
      VastuEntrySegment.n5: 'vastuSoma',
      VastuEntrySegment.n6: 'vastuBhujaga',
      VastuEntrySegment.n7: 'vastuAditi',
      VastuEntrySegment.n8: 'vastuDiti',

      // EAST
      VastuEntrySegment.e1: 'vastuShikhi',
      VastuEntrySegment.e2: 'vastuParjanya',
      VastuEntrySegment.e3: 'vastuJayanta',
      VastuEntrySegment.e4: 'vastuIndra',
      VastuEntrySegment.e5: 'vastuSurya',
      VastuEntrySegment.e6: 'vastuSatya',
      VastuEntrySegment.e7: 'vastuBhrisha',
      VastuEntrySegment.e8: 'vastuAkasha',

      // SOUTH
      VastuEntrySegment.s1: 'vastuAnila',
      VastuEntrySegment.s2: 'vastuPusha',
      VastuEntrySegment.s3: 'vastuVitatha',
      VastuEntrySegment.s4: 'vastuGrihakshata',
      VastuEntrySegment.s5: 'vastuYama',
      VastuEntrySegment.s6: 'vastuGandharva',
      VastuEntrySegment.s7: 'vastuBhringaraja',
      VastuEntrySegment.s8: 'vastuMriga',

      // WEST
      VastuEntrySegment.w1: 'vastuPitra',
      VastuEntrySegment.w2: 'vastuDauvarika',
      VastuEntrySegment.w3: 'vastuSugriva',
      VastuEntrySegment.w4: 'vastuPushpadanta',
      VastuEntrySegment.w5: 'vastuVaruna',
      VastuEntrySegment.w6: 'vastuAsura',
      VastuEntrySegment.w7: 'vastuShosha',
      VastuEntrySegment.w8: 'vastuPapayakshma',
    };

    test('supports all 32 entrance segments', () {
      expect(repository.supportedSegments.length, 32);
      expect(
        repository.supportedSegments.toSet(),
        expectedDeities.keys.toSet(),
      );
    });

    for (final entry in expectedDeities.entries) {
      test('${entry.key.code} maps to ${entry.value}', () {
        final deity = repository.getDeity(entry.key);

        expect(deity.segment, entry.key);
        expect(deity.deityKey, entry.value);
      });
    }

    test('W4 maps to Pushpadanta', () {
      final deity = repository.getDeity(VastuEntrySegment.w4);

      expect(deity.deityKey, 'vastuPushpadanta');
    });

    test('W5 maps to Varuna', () {
      final deity = repository.getDeity(VastuEntrySegment.w5);

      expect(deity.deityKey, 'vastuVaruna');
    });
  });
}
