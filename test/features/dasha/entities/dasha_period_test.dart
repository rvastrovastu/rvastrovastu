import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_period.dart';

void main() {
  group('DashaPeriod.contains', () {
    final start = DateTime(2026, 1, 1, 12, 0, 0);
    final end = DateTime(2027, 1, 1, 12, 0, 0);

    final period = DashaPeriod(
      planet: DashaPlanet.sun,
      startDate: start,
      endDate: end,
      level: 1,
    );

    test('includes exact start date', () {
      expect(period.contains(start), isTrue);
    });

    test('includes a date inside the period', () {
      final middle = DateTime(2026, 6, 15, 12, 0, 0);

      expect(period.contains(middle), isTrue);
    });

    test('excludes exact end date', () {
      expect(period.contains(end), isFalse);
    });

    test('excludes a date after the end date', () {
      final afterEnd = end.add(const Duration(microseconds: 1));

      expect(period.contains(afterEnd), isFalse);
    });

    test('excludes a date before the start date', () {
      final beforeStart = start.subtract(const Duration(microseconds: 1));

      expect(period.contains(beforeStart), isFalse);
    });

    test('uses half-open interval [start, end)', () {
      expect(period.contains(start), isTrue);
      expect(period.contains(end), isFalse);
    });
  });
}
