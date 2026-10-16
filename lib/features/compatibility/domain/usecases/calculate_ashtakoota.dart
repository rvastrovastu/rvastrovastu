import '../entities/compatibility_result.dart';
import '../entities/koota_score.dart';

/// Traditional Ashtakoota Guna Milan calculator.
///
/// Inputs use the bride's and groom's Moon nakshatra and Moon sign.
/// Table conventions can differ between Jyotish traditions. In particular,
/// verify the Vashya and Yoni tables against the reference chosen for release.
///
/// This score is a traditional astrological assessment, not a validated
/// prediction of relationship quality or success.
class CalculateAshtakoota {
  static const List<String> nakshatras = [
    'Ashwini',
    'Bharani',
    'Krittika',
    'Rohini',
    'Mrigashira',
    'Ardra',
    'Punarvasu',
    'Pushya',
    'Ashlesha',
    'Magha',
    'Purva Phalguni',
    'Uttara Phalguni',
    'Hasta',
    'Chitra',
    'Swati',
    'Vishakha',
    'Anuradha',
    'Jyeshtha',
    'Mula',
    'Purva Ashadha',
    'Uttara Ashadha',
    'Shravana',
    'Dhanishtha',
    'Shatabhisha',
    'Purva Bhadrapada',
    'Uttara Bhadrapada',
    'Revati',
  ];

  static const List<String> rashis = [
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

  static const Map<String, int> _varna = {
    'Cancer': 4,
    'Scorpio': 4,
    'Pisces': 4,
    'Aries': 3,
    'Leo': 3,
    'Sagittarius': 3,
    'Taurus': 2,
    'Virgo': 2,
    'Capricorn': 2,
    'Gemini': 1,
    'Libra': 1,
    'Aquarius': 1,
  };

  static const Map<String, String> _vashya = {
    'Gemini': 'Dvipada',
    'Virgo': 'Dvipada',
    'Libra': 'Dvipada',
    'Aries': 'Chatushpada',
    'Taurus': 'Chatushpada',
    'Leo': 'Chatushpada',
    'Sagittarius': 'Chatushpada',
    'Cancer': 'Jalachara',
    'Capricorn': 'Jalachara',
    'Aquarius': 'Jalachara',
    'Pisces': 'Jalachara',
    'Scorpio': 'Keeta',
  };

  static const Map<String, String> _yoni = {
    'Ashwini': 'Horse',
    'Shatabhisha': 'Horse',
    'Bharani': 'Elephant',
    'Revati': 'Elephant',
    'Krittika': 'Sheep',
    'Pushya': 'Sheep',
    'Rohini': 'Serpent',
    'Mrigashira': 'Serpent',
    'Ardra': 'Dog',
    'Mula': 'Dog',
    'Punarvasu': 'Cat',
    'Ashlesha': 'Cat',
    'Magha': 'Rat',
    'Purva Phalguni': 'Rat',
    'Uttara Phalguni': 'Cow',
    'Uttara Bhadrapada': 'Cow',
    'Hasta': 'Buffalo',
    'Swati': 'Buffalo',
    'Chitra': 'Tiger',
    'Vishakha': 'Tiger',
    'Anuradha': 'Deer',
    'Jyeshtha': 'Deer',
    'Purva Ashadha': 'Monkey',
    'Shravana': 'Monkey',
    'Uttara Ashadha': 'Mongoose',
    'Dhanishtha': 'Lion',
    'Purva Bhadrapada': 'Lion',
  };

  static const Map<String, String> _gana = {
    'Ashwini': 'Deva',
    'Mrigashira': 'Deva',
    'Punarvasu': 'Deva',
    'Pushya': 'Deva',
    'Hasta': 'Deva',
    'Swati': 'Deva',
    'Anuradha': 'Deva',
    'Shravana': 'Deva',
    'Revati': 'Deva',
    'Bharani': 'Manushya',
    'Rohini': 'Manushya',
    'Ardra': 'Manushya',
    'Purva Phalguni': 'Manushya',
    'Uttara Phalguni': 'Manushya',
    'Purva Ashadha': 'Manushya',
    'Uttara Ashadha': 'Manushya',
    'Purva Bhadrapada': 'Manushya',
    'Uttara Bhadrapada': 'Manushya',
    'Krittika': 'Rakshasa',
    'Ashlesha': 'Rakshasa',
    'Magha': 'Rakshasa',
    'Chitra': 'Rakshasa',
    'Vishakha': 'Rakshasa',
    'Jyeshtha': 'Rakshasa',
    'Mula': 'Rakshasa',
    'Dhanishtha': 'Rakshasa',
    'Shatabhisha': 'Rakshasa',
  };

  static const Map<String, String> _nadi = {
    'Ashwini': 'Adi',
    'Ardra': 'Adi',
    'Punarvasu': 'Adi',
    'Uttara Phalguni': 'Adi',
    'Hasta': 'Adi',
    'Jyeshtha': 'Adi',
    'Mula': 'Adi',
    'Shatabhisha': 'Adi',
    'Purva Bhadrapada': 'Adi',
    'Bharani': 'Madhya',
    'Mrigashira': 'Madhya',
    'Pushya': 'Madhya',
    'Purva Phalguni': 'Madhya',
    'Chitra': 'Madhya',
    'Anuradha': 'Madhya',
    'Purva Ashadha': 'Madhya',
    'Dhanishtha': 'Madhya',
    'Uttara Bhadrapada': 'Madhya',
    'Krittika': 'Antya',
    'Rohini': 'Antya',
    'Ashlesha': 'Antya',
    'Magha': 'Antya',
    'Swati': 'Antya',
    'Vishakha': 'Antya',
    'Uttara Ashadha': 'Antya',
    'Shravana': 'Antya',
    'Revati': 'Antya',
  };

  static const Map<String, String> _signLord = {
    'Aries': 'Mars',
    'Scorpio': 'Mars',
    'Taurus': 'Venus',
    'Libra': 'Venus',
    'Gemini': 'Mercury',
    'Virgo': 'Mercury',
    'Cancer': 'Moon',
    'Leo': 'Sun',
    'Sagittarius': 'Jupiter',
    'Pisces': 'Jupiter',
    'Capricorn': 'Saturn',
    'Aquarius': 'Saturn',
  };

  static const Map<String, Map<String, double>> _friendship = {
    'Sun': {
      'Sun': 5,
      'Moon': 5,
      'Mars': 5,
      'Mercury': 4,
      'Jupiter': 5,
      'Venus': 0,
      'Saturn': 0,
    },
    'Moon': {
      'Sun': 5,
      'Moon': 5,
      'Mars': 4,
      'Mercury': 1,
      'Jupiter': 4,
      'Venus': 0.5,
      'Saturn': 0.5,
    },
    'Mars': {
      'Sun': 5,
      'Moon': 4,
      'Mars': 5,
      'Mercury': 0.5,
      'Jupiter': 5,
      'Venus': 3,
      'Saturn': 0.5,
    },
    'Mercury': {
      'Sun': 4,
      'Moon': 1,
      'Mars': 0.5,
      'Mercury': 5,
      'Jupiter': 0.5,
      'Venus': 5,
      'Saturn': 4,
    },
    'Jupiter': {
      'Sun': 5,
      'Moon': 4,
      'Mars': 5,
      'Mercury': 0.5,
      'Jupiter': 5,
      'Venus': 0.5,
      'Saturn': 3,
    },
    'Venus': {
      'Sun': 0,
      'Moon': 0.5,
      'Mars': 3,
      'Mercury': 5,
      'Jupiter': 0.5,
      'Venus': 5,
      'Saturn': 5,
    },
    'Saturn': {
      'Sun': 0,
      'Moon': 0.5,
      'Mars': 0.5,
      'Mercury': 4,
      'Jupiter': 3,
      'Venus': 5,
      'Saturn': 5,
    },
  };

  static const Map<String, Map<String, double>> _ganaScores = {
    'Deva': {'Deva': 6, 'Manushya': 5, 'Rakshasa': 1},
    'Manushya': {'Deva': 6, 'Manushya': 6, 'Rakshasa': 0},
    'Rakshasa': {'Deva': 0, 'Manushya': 0, 'Rakshasa': 6},
  };

  CompatibilityResult call({
    required String brideNakshatra,
    required String brideRashi,
    required String groomNakshatra,
    required String groomRashi,
  }) {
    final bn = _canonical(brideNakshatra, nakshatras, 'bride nakshatra');
    final gn = _canonical(groomNakshatra, nakshatras, 'groom nakshatra');
    final br = _canonical(brideRashi, rashis, 'bride rashi');
    final gr = _canonical(groomRashi, rashis, 'groom rashi');

    final brideIndex = nakshatras.indexOf(bn);
    final groomIndex = nakshatras.indexOf(gn);
    final brideSign = rashis.indexOf(br);
    final groomSign = rashis.indexOf(gr);

    final scores = <KootaScore>[
      KootaScore(
        name: 'Varna',
        score: _varna[gr]! >= _varna[br]! ? 1 : 0,
        maximum: 1,
        explanation: 'Traditional sign-based Varna comparison.',
      ),
      KootaScore(
        name: 'Vashya',
        score: _vashyaScore(br, gr),
        maximum: 2,
        explanation:
            'Initial sign-group compatibility convention; verify '
            'the selected traditional table before release.',
      ),
      KootaScore(
        name: 'Tara',
        score: _taraScore(brideIndex, groomIndex),
        maximum: 3,
        explanation: 'Counts the nakshatra distance in both directions.',
      ),
      KootaScore(
        name: 'Yoni',
        score: _yoniScore(_yoni[bn]!, _yoni[gn]!),
        maximum: 4,
        explanation:
            'Animal-yoni comparison; enemy classifications require '
            'verification against the chosen reference table.',
      ),
      KootaScore(
        name: 'Graha Maitri',
        score: _friendship[_signLord[br]]![_signLord[gr]]!,
        maximum: 5,
        explanation: 'Moon-sign lords, with bride as the row.',
      ),
      KootaScore(
        name: 'Gana',
        score: _ganaScores[_gana[bn]]![_gana[gn]]!,
        maximum: 6,
        explanation: 'Traditional Deva, Manushya, and Rakshasa comparison.',
      ),
      KootaScore(
        name: 'Bhakoot',
        score: _bhakootScore(brideSign, groomSign),
        maximum: 7,
        explanation: 'Traditional 2/12, 5/9, and 6/8 sign-distance rule.',
      ),
      KootaScore(
        name: 'Nadi',
        score: _nadi[bn] == _nadi[gn] ? 0 : 8,
        maximum: 8,
        explanation: 'Traditional same-Nadi check.',
      ),
    ];

    return CompatibilityResult(
      kootas: List.unmodifiable(scores),
      traditionalFlags: [
        if (_nadi[bn] == _nadi[gn])
          'Traditional Nadi dosha flag: both nakshatras share a Nadi.',
        if (_bhakootScore(brideSign, groomSign) == 0)
          'Traditional Bhakoot dosha flag: signs have a 2/12, 5/9, '
              'or 6/8 relationship.',
      ],
    );
  }

  String _canonical(String value, List<String> valid, String field) {
    for (final candidate in valid) {
      if (candidate.toLowerCase() == value.trim().toLowerCase()) {
        return candidate;
      }
    }
    throw ArgumentError.value(value, field, 'Unsupported value.');
  }

  double _taraScore(int bride, int groom) {
    final forward = (groom - bride + 27) % 27 + 1;
    final reverse = (bride - groom + 27) % 27 + 1;
    final forwardTara = (forward - 1) % 9 + 1;
    final reverseTara = (reverse - 1) % 9 + 1;
    final forwardGood = !{3, 5, 7}.contains(forwardTara);
    final reverseGood = !{3, 5, 7}.contains(reverseTara);

    if (forwardGood && reverseGood) return 3;
    if (forwardGood || reverseGood) return 1.5;
    return 0;
  }

  double _vashyaScore(String bride, String groom) {
    // Muhurta Chintamani convention. Rows are bride groups; columns
    // are groom groups. Other Jyotish traditions may use another table.
    const groups = ['Dvipada', 'Chatushpada', 'Jalachara', 'Keeta'];
    const scores = <List<double>>[
      [2, 0.5, 0.5, 1],
      [0.5, 2, 2, 2],
      [0.5, 2, 2, 2],
      [1, 2, 2, 2],
    ];

    final brideGroup = groups.indexOf(_vashya[bride]!);
    final groomGroup = groups.indexOf(_vashya[groom]!);

    if (brideGroup < 0 || groomGroup < 0) {
      throw StateError('Missing Vashya group for a rashi.');
    }

    return scores[brideGroup][groomGroup];
  }

  double _yoniScore(String bride, String groom) {
    // Muhurta Chintamani Yoni chakra, with the published corrections:
    // Horse/Buffalo = 0 and Mongoose/Monkey = 2.
    const animals = [
      'Horse',
      'Elephant',
      'Sheep',
      'Serpent',
      'Dog',
      'Cat',
      'Rat',
      'Cow',
      'Buffalo',
      'Tiger',
      'Deer',
      'Monkey',
      'Mongoose',
      'Lion',
    ];

    const scores = <List<double>>[
      [4, 2, 3, 2, 2, 3, 3, 3, 0, 1, 3, 2, 2, 1],
      [2, 4, 3, 2, 2, 3, 3, 3, 3, 2, 2, 2, 2, 0],
      [3, 3, 4, 3, 2, 3, 1, 3, 3, 1, 3, 0, 3, 1],
      [2, 2, 3, 4, 2, 2, 1, 1, 2, 2, 2, 2, 0, 2],
      [2, 2, 2, 2, 4, 1, 1, 2, 2, 1, 0, 2, 2, 1],
      [2, 2, 3, 2, 1, 4, 0, 2, 2, 1, 2, 2, 2, 2],
      [2, 2, 2, 1, 1, 0, 4, 2, 2, 2, 2, 2, 2, 1],
      [3, 2, 3, 1, 2, 2, 2, 4, 3, 0, 3, 2, 3, 1],
      [0, 3, 3, 2, 2, 2, 2, 3, 4, 1, 2, 2, 2, 3],
      [1, 2, 1, 2, 1, 1, 2, 0, 1, 4, 2, 1, 2, 2],
      [3, 2, 3, 2, 0, 2, 2, 3, 2, 1, 4, 2, 2, 2],
      [2, 3, 0, 2, 2, 2, 2, 2, 2, 1, 2, 4, 2, 3],
      [2, 2, 3, 0, 2, 2, 2, 3, 2, 2, 2, 2, 4, 2],
      [1, 0, 1, 2, 1, 2, 1, 1, 3, 2, 2, 2, 2, 4],
    ];

    final brideAnimal = animals.indexOf(bride);
    final groomAnimal = animals.indexOf(groom);

    if (brideAnimal < 0 || groomAnimal < 0) {
      throw StateError('Missing Yoni animal for a nakshatra.');
    }

    return scores[brideAnimal][groomAnimal];
  }

  double _bhakootScore(int bride, int groom) {
    final distance = (groom - bride + 12) % 12;
    const doshaDistances = {1, 4, 5, 7, 8, 11};
    return doshaDistances.contains(distance) ? 0 : 7;
  }
}
