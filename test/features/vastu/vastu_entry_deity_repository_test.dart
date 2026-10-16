import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/vastu/data/repositories/local_vastu_entry_deity_repository.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_segment.dart';

void main() {
  const repository = LocalVastuEntryDeityRepository();

  group('LocalVastuEntryDeityRepository', () {
    test('defines all 32 cardinal entrance segments', () {
      expect(repository.supportedSegments, hasLength(32));
      expect(repository.supportedSegments.toSet(), hasLength(32));
    });

    test('maps north entrance padas correctly', () {
      expect(repository.getDeity(VastuEntrySegment.n1).deityKey, 'vastuRoga');
      expect(repository.getDeity(VastuEntrySegment.n2).deityKey, 'vastuNaga');
      expect(repository.getDeity(VastuEntrySegment.n3).deityKey, 'vastuMukhya');
      expect(
        repository.getDeity(VastuEntrySegment.n4).deityKey,
        'vastuBhallata',
      );
      expect(repository.getDeity(VastuEntrySegment.n5).deityKey, 'vastuSoma');
      expect(
        repository.getDeity(VastuEntrySegment.n6).deityKey,
        'vastuBhujaga',
      );
      expect(repository.getDeity(VastuEntrySegment.n7).deityKey, 'vastuAditi');
      expect(repository.getDeity(VastuEntrySegment.n8).deityKey, 'vastuDiti');
    });

    test('maps east entrance padas correctly', () {
      expect(repository.getDeity(VastuEntrySegment.e1).deityKey, 'vastuShikhi');
      expect(
        repository.getDeity(VastuEntrySegment.e2).deityKey,
        'vastuParjanya',
      );
      expect(
        repository.getDeity(VastuEntrySegment.e3).deityKey,
        'vastuJayanta',
      );
      expect(repository.getDeity(VastuEntrySegment.e4).deityKey, 'vastuIndra');
      expect(repository.getDeity(VastuEntrySegment.e5).deityKey, 'vastuSurya');
      expect(repository.getDeity(VastuEntrySegment.e6).deityKey, 'vastuSatya');
      expect(
        repository.getDeity(VastuEntrySegment.e7).deityKey,
        'vastuBhrisha',
      );
      expect(repository.getDeity(VastuEntrySegment.e8).deityKey, 'vastuAkasha');
    });

    test('maps south entrance padas correctly', () {
      expect(repository.getDeity(VastuEntrySegment.s1).deityKey, 'vastuAnila');
      expect(repository.getDeity(VastuEntrySegment.s2).deityKey, 'vastuPusha');
      expect(
        repository.getDeity(VastuEntrySegment.s3).deityKey,
        'vastuVitatha',
      );
      expect(
        repository.getDeity(VastuEntrySegment.s4).deityKey,
        'vastuGrihakshata',
      );
      expect(repository.getDeity(VastuEntrySegment.s5).deityKey, 'vastuYama');
      expect(
        repository.getDeity(VastuEntrySegment.s6).deityKey,
        'vastuGandharva',
      );
      expect(
        repository.getDeity(VastuEntrySegment.s7).deityKey,
        'vastuBhringaraja',
      );
      expect(repository.getDeity(VastuEntrySegment.s8).deityKey, 'vastuMriga');
    });

    test('maps west entrance padas correctly', () {
      expect(repository.getDeity(VastuEntrySegment.w1).deityKey, 'vastuPitra');
      expect(
        repository.getDeity(VastuEntrySegment.w2).deityKey,
        'vastuDauvarika',
      );
      expect(
        repository.getDeity(VastuEntrySegment.w3).deityKey,
        'vastuSugriva',
      );
      expect(
        repository.getDeity(VastuEntrySegment.w4).deityKey,
        'vastuPushpadanta',
      );
      expect(repository.getDeity(VastuEntrySegment.w5).deityKey, 'vastuVaruna');
      expect(repository.getDeity(VastuEntrySegment.w6).deityKey, 'vastuAsura');
      expect(repository.getDeity(VastuEntrySegment.w7).deityKey, 'vastuShosha');
      expect(
        repository.getDeity(VastuEntrySegment.w8).deityKey,
        'vastuPapayakshma',
      );
    });

    test('W4 and W5 preserve existing deity mapping', () {
      expect(
        repository.getDeity(VastuEntrySegment.w4).deityKey,
        'vastuPushpadanta',
      );
      expect(repository.getDeity(VastuEntrySegment.w5).deityKey, 'vastuVaruna');
    });
  });
}
