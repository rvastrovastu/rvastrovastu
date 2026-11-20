import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/vastu/layout/data/vastu_cloud_sync.dart';
import 'package:rv_astro_vastu/features/vastu/layout/domain/vastu_layout.dart';

VastuLayout plan(String id, DateTime at, {String? image}) =>
    VastuLayout(id: id, name: id, updatedAt: at, imageFile: image);

CloudVastuPlan cloud(
  String id,
  DateTime at, {
  bool deleted = false,
  String? image,
  String? report,
}) => CloudVastuPlan(
  id: id,
  updatedAt: at,
  deleted: deleted,
  layout: deleted ? null : plan(id, at, image: image),
  imagePath: image == null ? null : 'user/$image',
  reportTxn: report,
);

void main() {
  final t1 = DateTime.utc(2026, 11, 1);
  final t2 = DateTime.utc(2026, 11, 2);

  test('a plan only on the phone is uploaded', () {
    final m = mergeVastuPlans([plan('a', t1)], const [], const {});
    expect(m.uploads.map((l) => l.id), ['a']);
    expect(m.keep.map((l) => l.id), ['a']);
  });

  test('a plan only in the account comes down with its picture', () {
    final m = mergeVastuPlans(const [], [cloud('a', t1, image: 'a_1.jpg')], const {});
    expect(m.keep.map((l) => l.id), ['a']);
    expect(m.downloads, {'a': 'user/a_1.jpg'});
    expect(m.uploads, isEmpty);
  });

  test('the copy changed last wins', () {
    final newerHere = mergeVastuPlans([plan('a', t2)], [cloud('a', t1)], const {});
    expect(newerHere.uploads.map((l) => l.id), ['a']);
    expect(newerHere.keep.single.updatedAt, t2);

    final newerThere = mergeVastuPlans([plan('a', t1)], [cloud('a', t2)], const {});
    expect(newerThere.uploads, isEmpty);
    expect(newerThere.keep.single.updatedAt, t2);
  });

  test('a plan deleted on another phone is removed here', () {
    final m = mergeVastuPlans([plan('a', t1)], [cloud('a', t2, deleted: true)], const {});
    expect(m.keep, isEmpty);
    expect(m.dropped.map((l) => l.id), ['a']);
  });

  test('a plan edited here after being deleted elsewhere comes back', () {
    final m = mergeVastuPlans([plan('a', t2)], [cloud('a', t1, deleted: true)], const {});
    expect(m.keep.map((l) => l.id), ['a']);
    expect(m.uploads.map((l) => l.id), ['a']);
  });

  test('a report bought on another phone is assigned here', () {
    final m = mergeVastuPlans(
      [plan('a', t1)],
      [cloud('a', t1, report: 'GPA.1')],
      const {},
    );
    expect(m.reports, {'a': 'GPA.1'});
    expect(m.uploads, isEmpty);
  });
}
