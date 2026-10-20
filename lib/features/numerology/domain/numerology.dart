/// Indian (Chaldean) numerology numbers.
class NumerologyReport {
  /// Mulank: the day of birth reduced to 1–9.
  final int mulank;

  /// Bhagyank: every digit of the full date of birth reduced to 1–9.
  final int bhagyank;

  /// Name number reduced to 1–9, or `null` when the name has no letters.
  final int? nameNumber;

  /// Name total before reduction (the "compound" number).
  final int? nameCompound;

  /// Personal year for [year]: birth day + birth month + year, reduced.
  final int personalYear;
  final int year;

  const NumerologyReport({
    required this.mulank,
    required this.bhagyank,
    required this.nameNumber,
    required this.nameCompound,
    required this.personalYear,
    required this.year,
  });
}

class Numerology {
  const Numerology();

  /// Chaldean letter values (no letter is 9).
  static const Map<String, int> chaldean = {
    'A': 1, 'I': 1, 'J': 1, 'Q': 1, 'Y': 1,
    'B': 2, 'K': 2, 'R': 2,
    'C': 3, 'G': 3, 'L': 3, 'S': 3,
    'D': 4, 'M': 4, 'T': 4,
    'E': 5, 'H': 5, 'N': 5, 'X': 5,
    'U': 6, 'V': 6, 'W': 6,
    'O': 7, 'Z': 7,
    'F': 8, 'P': 8,
  };

  /// Ruling planet for 1–9, as used in Indian numerology.
  static const Map<int, String> rulingPlanet = {
    1: 'Sun',
    2: 'Moon',
    3: 'Jupiter',
    4: 'Rahu',
    5: 'Mercury',
    6: 'Venus',
    7: 'Ketu',
    8: 'Saturn',
    9: 'Mars',
  };

  /// Repeatedly sums digits until a single digit 1–9 remains.
  static int reduce(int value) {
    var n = value.abs();
    if (n == 0) return 0;
    while (n > 9) {
      var sum = 0;
      while (n > 0) {
        sum += n % 10;
        n ~/= 10;
      }
      n = sum;
    }
    return n;
  }

  static int _digitSum(int value) {
    var n = value.abs();
    var sum = 0;
    while (n > 0) {
      sum += n % 10;
      n ~/= 10;
    }
    return sum;
  }

  /// Chaldean total of the Latin letters in [name], or `null` if none.
  static int? nameTotal(String name) {
    var total = 0;
    var letters = 0;
    for (final rune in name.toUpperCase().runes) {
      final value = chaldean[String.fromCharCode(rune)];
      if (value != null) {
        total += value;
        letters++;
      }
    }
    return letters == 0 ? null : total;
  }

  NumerologyReport call({
    required DateTime dateOfBirth,
    required String name,
    required int year,
  }) {
    final mulank = reduce(dateOfBirth.day);
    final bhagyank = reduce(
      _digitSum(dateOfBirth.day) +
          _digitSum(dateOfBirth.month) +
          _digitSum(dateOfBirth.year),
    );
    final compound = nameTotal(name);
    final personalYear = reduce(
      _digitSum(dateOfBirth.day) +
          _digitSum(dateOfBirth.month) +
          _digitSum(year),
    );

    return NumerologyReport(
      mulank: mulank,
      bhagyank: bhagyank,
      nameNumber: compound == null ? null : reduce(compound),
      nameCompound: compound,
      personalYear: personalYear,
      year: year,
    );
  }
}
