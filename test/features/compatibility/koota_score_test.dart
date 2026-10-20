import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/compatibility/domain/entities/koota_score.dart';

void main() {
  group('KootaScore percentage', () {
    test('calculates percentage correctly', () {
      const score = KootaScore(
        name: 'Varna',
        score: 0.5,
        maximum: 1,
        explanation: 'Test explanation',
      );

      expect(score.percentage, 50);
    });

    test('returns 100 for a full score', () {
      const score = KootaScore(
        name: 'Nadi',
        score: 8,
        maximum: 8,
        explanation: 'Test explanation',
      );

      expect(score.percentage, 100);
    });

    test('returns zero for a zero score', () {
      const score = KootaScore(
        name: 'Yoni',
        score: 0,
        maximum: 4,
        explanation: 'Test explanation',
      );

      expect(score.percentage, 0);
    });
  });
}
