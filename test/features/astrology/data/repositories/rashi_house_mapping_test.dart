import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Whole Sign Rashi House Mapping', () {
    const signNames = [
      'Aries',
      'Taurus',
      'Gemini',
      'Cancer',
      'Leo',
      'Virgo',
      'Libra',
      'Scorpio',
      'Sagittarius',
      'Capricorn',
      'Aquarius',
      'Pisces',
    ];

    int houseForSign({
      required int ascendantSignIndex,
      required int signIndex,
    }) {
      return ((signIndex - ascendantSignIndex) % 12 + 12) % 12 + 1;
    }

    test('Aries ascendant maps houses sequentially', () {
      const ascendant = 0;

      expect(
        List.generate(
          12,
          (house) => signNames[(ascendant + house) % 12],
        ),
        [
          'Aries',
          'Taurus',
          'Gemini',
          'Cancer',
          'Leo',
          'Virgo',
          'Libra',
          'Scorpio',
          'Sagittarius',
          'Capricorn',
          'Aquarius',
          'Pisces',
        ],
      );
    });

    test('Cancer ascendant wraps correctly', () {
      const ascendant = 3;

      expect(
        List.generate(
          12,
          (house) => signNames[(ascendant + house) % 12],
        ),
        [
          'Cancer',
          'Leo',
          'Virgo',
          'Libra',
          'Scorpio',
          'Sagittarius',
          'Capricorn',
          'Aquarius',
          'Pisces',
          'Aries',
          'Taurus',
          'Gemini',
        ],
      );
    });

    test('Pisces ascendant wraps correctly', () {
      const ascendant = 11;

      expect(
        List.generate(
          12,
          (house) => signNames[(ascendant + house) % 12],
        ),
        [
          'Pisces',
          'Aries',
          'Taurus',
          'Gemini',
          'Cancer',
          'Leo',
          'Virgo',
          'Libra',
          'Scorpio',
          'Sagittarius',
          'Capricorn',
          'Aquarius',
        ],
      );
    });

    test('every sign maps to exactly one house', () {
      for (var ascendant = 0; ascendant < 12; ascendant++) {
        final houses = List.generate(
          12,
          (house) => (ascendant + house) % 12,
        );

        expect(houses.toSet().length, 12);
      }
    });

    test('house formula returns 1 for Lagna sign', () {
      for (var ascendant = 0; ascendant < 12; ascendant++) {
        expect(
          houseForSign(
            ascendantSignIndex: ascendant,
            signIndex: ascendant,
          ),
          1,
        );
      }
    });

    test('house formula returns 7 for opposite sign', () {
      for (var ascendant = 0; ascendant < 12; ascendant++) {
        final opposite = (ascendant + 6) % 12;

        expect(
          houseForSign(
            ascendantSignIndex: ascendant,
            signIndex: opposite,
          ),
          7,
        );
      }
    });

    test('house formula returns 12 for previous sign', () {
      for (var ascendant = 0; ascendant < 12; ascendant++) {
        final previous = (ascendant + 11) % 12;

        expect(
          houseForSign(
            ascendantSignIndex: ascendant,
            signIndex: previous,
          ),
          12,
        );
      }
    });
  });
}
