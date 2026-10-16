import '../../domain/entities/vastu_entry_deity.dart';
import '../../domain/entities/vastu_entry_segment.dart';

class LocalVastuEntryDeityRepository {
  const LocalVastuEntryDeityRepository();

  static const _deities = <VastuEntrySegment, VastuEntryDeity>{
    // NORTH
    VastuEntrySegment.n1: VastuEntryDeity(
      segment: VastuEntrySegment.n1,
      deityKey: 'vastuRoga',
    ),
    VastuEntrySegment.n2: VastuEntryDeity(
      segment: VastuEntrySegment.n2,
      deityKey: 'vastuNaga',
    ),
    VastuEntrySegment.n3: VastuEntryDeity(
      segment: VastuEntrySegment.n3,
      deityKey: 'vastuMukhya',
    ),
    VastuEntrySegment.n4: VastuEntryDeity(
      segment: VastuEntrySegment.n4,
      deityKey: 'vastuBhallata',
    ),
    VastuEntrySegment.n5: VastuEntryDeity(
      segment: VastuEntrySegment.n5,
      deityKey: 'vastuSoma',
    ),
    VastuEntrySegment.n6: VastuEntryDeity(
      segment: VastuEntrySegment.n6,
      deityKey: 'vastuBhujaga',
    ),
    VastuEntrySegment.n7: VastuEntryDeity(
      segment: VastuEntrySegment.n7,
      deityKey: 'vastuAditi',
    ),
    VastuEntrySegment.n8: VastuEntryDeity(
      segment: VastuEntrySegment.n8,
      deityKey: 'vastuDiti',
    ),

    // EAST
    VastuEntrySegment.e1: VastuEntryDeity(
      segment: VastuEntrySegment.e1,
      deityKey: 'vastuShikhi',
    ),
    VastuEntrySegment.e2: VastuEntryDeity(
      segment: VastuEntrySegment.e2,
      deityKey: 'vastuParjanya',
    ),
    VastuEntrySegment.e3: VastuEntryDeity(
      segment: VastuEntrySegment.e3,
      deityKey: 'vastuJayanta',
    ),
    VastuEntrySegment.e4: VastuEntryDeity(
      segment: VastuEntrySegment.e4,
      deityKey: 'vastuIndra',
    ),
    VastuEntrySegment.e5: VastuEntryDeity(
      segment: VastuEntrySegment.e5,
      deityKey: 'vastuSurya',
    ),
    VastuEntrySegment.e6: VastuEntryDeity(
      segment: VastuEntrySegment.e6,
      deityKey: 'vastuSatya',
    ),
    VastuEntrySegment.e7: VastuEntryDeity(
      segment: VastuEntrySegment.e7,
      deityKey: 'vastuBhrisha',
    ),
    VastuEntrySegment.e8: VastuEntryDeity(
      segment: VastuEntrySegment.e8,
      deityKey: 'vastuAkasha',
    ),

    // SOUTH
    VastuEntrySegment.s1: VastuEntryDeity(
      segment: VastuEntrySegment.s1,
      deityKey: 'vastuAnila',
    ),
    VastuEntrySegment.s2: VastuEntryDeity(
      segment: VastuEntrySegment.s2,
      deityKey: 'vastuPusha',
    ),
    VastuEntrySegment.s3: VastuEntryDeity(
      segment: VastuEntrySegment.s3,
      deityKey: 'vastuVitatha',
    ),
    VastuEntrySegment.s4: VastuEntryDeity(
      segment: VastuEntrySegment.s4,
      deityKey: 'vastuGrihakshata',
    ),
    VastuEntrySegment.s5: VastuEntryDeity(
      segment: VastuEntrySegment.s5,
      deityKey: 'vastuYama',
    ),
    VastuEntrySegment.s6: VastuEntryDeity(
      segment: VastuEntrySegment.s6,
      deityKey: 'vastuGandharva',
    ),
    VastuEntrySegment.s7: VastuEntryDeity(
      segment: VastuEntrySegment.s7,
      deityKey: 'vastuBhringaraja',
    ),
    VastuEntrySegment.s8: VastuEntryDeity(
      segment: VastuEntrySegment.s8,
      deityKey: 'vastuMriga',
    ),

    // WEST
    VastuEntrySegment.w1: VastuEntryDeity(
      segment: VastuEntrySegment.w1,
      deityKey: 'vastuPitra',
    ),
    VastuEntrySegment.w2: VastuEntryDeity(
      segment: VastuEntrySegment.w2,
      deityKey: 'vastuDauvarika',
    ),
    VastuEntrySegment.w3: VastuEntryDeity(
      segment: VastuEntrySegment.w3,
      deityKey: 'vastuSugriva',
    ),
    VastuEntrySegment.w4: VastuEntryDeity(
      segment: VastuEntrySegment.w4,
      deityKey: 'vastuPushpadanta',
    ),
    VastuEntrySegment.w5: VastuEntryDeity(
      segment: VastuEntrySegment.w5,
      deityKey: 'vastuVaruna',
    ),
    VastuEntrySegment.w6: VastuEntryDeity(
      segment: VastuEntrySegment.w6,
      deityKey: 'vastuAsura',
    ),
    VastuEntrySegment.w7: VastuEntryDeity(
      segment: VastuEntrySegment.w7,
      deityKey: 'vastuShosha',
    ),
    VastuEntrySegment.w8: VastuEntryDeity(
      segment: VastuEntrySegment.w8,
      deityKey: 'vastuPapayakshma',
    ),
  };

  List<VastuEntrySegment> get supportedSegments =>
      List.unmodifiable(_deities.keys);

  VastuEntryDeity getDeity(VastuEntrySegment segment) {
    final deity = _deities[segment];

    if (deity == null) {
      throw UnsupportedError(
        'Vastu entrance deity is not defined for ${segment.code}.',
      );
    }

    return deity;
  }
}
