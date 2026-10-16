import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/compatibility/domain/entities/compatibility_result.dart';
import 'package:rv_astro_vastu/features/compatibility/domain/usecases/calculate_ashtakoota.dart';

void main() {
  late CalculateAshtakoota calculator;

  setUp(() {
    calculator = CalculateAshtakoota();
  });

  CompatibilityResult calculate({
    String brideNakshatra = 'Ashwini',
    String brideRashi = 'Aries',
    String groomNakshatra = 'Ashwini',
    String groomRashi = 'Aries',
  }) {
    return calculator(
      brideNakshatra: brideNakshatra,
      brideRashi: brideRashi,
      groomNakshatra: groomNakshatra,
      groomRashi: groomRashi,
    );
  }

  group('Ashtakoota result structure', () {
    test('returns all eight kootas in the expected order', () {
      final result = calculate();

      expect(result.hasEightKootas, isTrue);
      expect(result.kootas.map((koota) => koota.name).toList(), [
        'Varna',
        'Vashya',
        'Tara',
        'Yoni',
        'Graha Maitri',
        'Gana',
        'Bhakoot',
        'Nadi',
      ]);
    });

    test('maximum possible score is 36', () {
      final result = calculate();

      expect(result.maximumScore, 36);
      expect(result.totalScore, inInclusiveRange(0, 36));
    });

    test('same Ashwini and Aries produce expected baseline scores', () {
      final result = calculate();

      expect(result.kootas[0].score, 1); // Varna
      expect(result.kootas[1].score, 2); // Initial Vashya convention
      expect(result.kootas[2].score, 3); // Tara
      expect(result.kootas[3].score, 4); // Same Yoni
      expect(result.kootas[4].score, 5); // Same sign lord
      expect(result.kootas[5].score, 6); // Same Gana
      expect(result.kootas[6].score, 7); // Same sign
      expect(result.kootas[7].score, 0); // Same Nadi
      expect(result.totalScore, 28);
    });

    test('accepts case-insensitive input and surrounding whitespace', () {
      final result = calculate(
        brideNakshatra: '  ashWini ',
        brideRashi: ' ARIES ',
        groomNakshatra: 'ASHWINI',
        groomRashi: 'aries',
      );

      expect(result.hasEightKootas, isTrue);
    });

    test('rejects an unsupported nakshatra', () {
      expect(
        () => calculate(brideNakshatra: 'Unknown Nakshatra'),
        throwsArgumentError,
      );
    });

    test('rejects an unsupported rashi', () {
      expect(() => calculate(groomRashi: 'Unknown Rashi'), throwsArgumentError);
    });
  });

  group('Tara scoring', () {
    test('same nakshatra receives three Tara points', () {
      expect(calculate().kootas[2].score, 3);
    });

    test('scores one favorable Tara direction as 1.5', () {
      final result = calculate(
        brideNakshatra: 'Ashwini',
        groomNakshatra: 'Mrigashira',
      );

      expect(result.kootas[2].score, 1.5);
    });

    test('scores Tara correctly across the cycle boundary', () {
      final result = calculate(
        brideNakshatra: 'Revati',
        groomNakshatra: 'Bharani',
      );

      expect(result.kootas[2].score, 1.5);
    });
  });

  group('Bhakoot scoring', () {
    test('same sign receives seven points', () {
      expect(calculate().kootas[6].score, 7);
    });

    test('2/12 relationship receives zero points', () {
      expect(
        calculate(brideRashi: 'Aries', groomRashi: 'Taurus').kootas[6].score,
        0,
      );
    });

    test('5/9 relationship receives zero points', () {
      expect(
        calculate(brideRashi: 'Aries', groomRashi: 'Leo').kootas[6].score,
        0,
      );
    });

    test('6/8 relationship receives zero points', () {
      expect(
        calculate(brideRashi: 'Aries', groomRashi: 'Virgo').kootas[6].score,
        0,
      );
    });

    test('a non-dosha sign distance receives seven points', () {
      expect(
        calculate(brideRashi: 'Aries', groomRashi: 'Gemini').kootas[6].score,
        7,
      );
    });

    test('adds a traditional Bhakoot flag for a dosha relationship', () {
      final result = calculate(brideRashi: 'Aries', groomRashi: 'Taurus');

      expect(
        result.traditionalFlags.any((flag) => flag.contains('Bhakoot')),
        isTrue,
      );
    });
  });

  group('Nadi scoring', () {
    test('same Nadi receives zero and adds a traditional flag', () {
      final result = calculate(
        brideNakshatra: 'Ashwini',
        groomNakshatra: 'Ardra',
      );

      expect(result.kootas[7].score, 0);
      expect(
        result.traditionalFlags.any((flag) => flag.contains('Nadi')),
        isTrue,
      );
    });

    test('different Nadi receives eight points', () {
      final result = calculate(
        brideNakshatra: 'Ashwini',
        groomNakshatra: 'Bharani',
      );

      expect(result.kootas[7].score, 8);
    });
  });

  group('Gana scoring', () {
    test('same Deva Gana receives six points', () {
      expect(calculate().kootas[5].score, 6);
    });

    test('Manushya bride and Rakshasa groom receive zero points', () {
      final result = calculate(
        brideNakshatra: 'Bharani',
        groomNakshatra: 'Krittika',
      );

      expect(result.kootas[5].score, 0);
    });
  });

  group('Graha Maitri scoring', () {
    test('matching Moon-sign lords receive five points', () {
      expect(calculate().kootas[4].score, 5);
    });

    test('score follows the directional lord matrix', () {
      final result = calculate(brideRashi: 'Aries', groomRashi: 'Taurus');

      // Mars row, Venus column in the configured friendship table.
      expect(result.kootas[4].score, 3);
    });
  });

  group('Complete Vashya table', () {
    test('same Vashya group receives two points', () {
      final result = calculate(brideRashi: 'Aries', groomRashi: 'Leo');

      expect(result.kootas[1].score, 2);
    });

    test('Dvipada bride and Chatushpada groom receive half a point', () {
      final result = calculate(brideRashi: 'Gemini', groomRashi: 'Aries');

      expect(result.kootas[1].score, 0.5);
    });

    test('Keeta bride and Dvipada groom receive one point', () {
      final result = calculate(brideRashi: 'Scorpio', groomRashi: 'Gemini');

      expect(result.kootas[1].score, 1);
    });
  });

  group('Complete Yoni table', () {
    test('same Yoni receives four points', () {
      final result = calculate(
        brideNakshatra: 'Ashwini',
        groomNakshatra: 'Shatabhisha',
      );

      expect(result.kootas[3].score, 4);
    });

    test('great-enemy Horse and Buffalo receive zero points', () {
      final result = calculate(
        brideNakshatra: 'Ashwini',
        groomNakshatra: 'Hasta',
      );

      expect(result.kootas[3].score, 0);
    });

    test('friendly Horse and Sheep receive three points', () {
      final result = calculate(
        brideNakshatra: 'Ashwini',
        groomNakshatra: 'Krittika',
      );

      expect(result.kootas[3].score, 3);
    });

    test('neutral Horse and Elephant receive two points', () {
      final result = calculate(
        brideNakshatra: 'Ashwini',
        groomNakshatra: 'Bharani',
      );

      expect(result.kootas[3].score, 2);
    });

    test('Cat and Rat receive zero points', () {
      final result = calculate(
        brideNakshatra: 'Punarvasu',
        groomNakshatra: 'Magha',
      );

      expect(result.kootas[3].score, 0);
    });

    test('Mongoose and Monkey use the corrected matrix value', () {
      final result = calculate(
        brideNakshatra: 'Uttara Ashadha',
        groomNakshatra: 'Shravana',
      );

      expect(result.kootas[3].score, 2);
    });
  });
}
