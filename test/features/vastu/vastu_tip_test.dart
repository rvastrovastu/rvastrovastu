import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/vastu/data/repositories/local_vastu_tip_repository.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_category.dart';

void main() {
  const repository = LocalVastuTipRepository();

  test('returns a deterministic Vastu tip for the same date', () {
    final date = DateTime(2026, 9, 4);

    final first = repository.getTipForDate(date);
    final second = repository.getTipForDate(date);

    expect(first.title, equals(second.title));
    expect(first.description, equals(second.description));
    expect(first.direction, equals(second.direction));
    expect(first.action, equals(second.action));
    expect(first.category, equals(second.category));
  });

  test('returns a populated Vastu tip', () {
    final tip = repository.getTipForDate(DateTime(2026, 9, 4));

    expect(tip.title, isNotEmpty);
    expect(tip.description, isNotEmpty);
    expect(tip.direction, isNotEmpty);
    expect(tip.action, isNotEmpty);
    expect(tip.category, isA<VastuCategory>());
  });

  test('repository assigns the expected category to September 4 2026', () {
    final tip = repository.getTipForDate(DateTime(2026, 9, 4));

    expect(tip.category, equals(VastuCategory.northeast));
    expect(tip.direction, equals('Northeast'));
  });
}
