import '../astrology/domain/entities/kundali.dart';
import '../dosha/domain/entities/zodiac_signs.dart';
import '../yogas/domain/usecases/detect_yogas.dart';

/// How the Muntha's house colours the year (Tajik Neelakanthi): houses 9,
/// 10 and 11 are best, 1, 2, 3 and 5 good, the rest call for care.
enum MunthaTone { excellent, good, care }

MunthaTone munthaTone(int house) => const {9, 10, 11}.contains(house)
    ? MunthaTone.excellent
    : const {1, 2, 3, 5}.contains(house)
    ? MunthaTone.good
    : MunthaTone.care;

/// Muntha starts in the birth Lagna and moves one sign a year.
int munthaSignIndex(int natalLagna, int completedYears) =>
    (natalLagna + completedYears) % 12;

/// Years completed on [today] for someone born on [dateOfBirth], judged by
/// the calendar birthday (the solar return falls within a day of it).
int completedYearsOn(DateTime dateOfBirth, DateTime today) {
  var years = today.year - dateOfBirth.year;
  final birthday = DateTime(today.year, dateOfBirth.month, dateOfBirth.day);
  if (DateTime(today.year, today.month, today.day).isBefore(birthday)) years--;
  return years < 0 ? 0 : years;
}

/// One year's Tajik annual chart (Varshphal).
class Varshphal {
  /// Years completed when this chart begins; the chart covers year
  /// [completedYears] + 1 of life.
  final int completedYears;

  /// The moment the Sun returns to its sidereal birth longitude.
  final DateTime praveshUtc;

  /// [praveshUtc] on the birth place's clock.
  final DateTime praveshLocal;

  /// The annual chart, cast for the birth place.
  final Kundali chart;

  /// Sign index (0 = Aries) of the birth Lagna.
  final int natalLagna;

  /// Local start of each solar month of the year: the return itself, then
  /// each time the Sun enters the next sign. Empty when not computed.
  final List<DateTime> monthStarts;

  const Varshphal({
    required this.completedYears,
    required this.praveshUtc,
    required this.praveshLocal,
    required this.chart,
    required this.natalLagna,
    this.monthStarts = const [],
  });

  /// Sign index of the Sun at the return (the birth Sun sign).
  int get sunSign => zodiacSignIndex(
    chart.planets.firstWhere((p) => p.planet == 'Sun').sign,
  );

  /// Month by month: when each solar month starts and the year-chart house
  /// the Sun lights up during it.
  List<(DateTime start, int house)> get months => [
    for (var i = 0; i < monthStarts.length; i++)
      (monthStarts[i], houseFrom(lagnaSign, (sunSign + i) % 12)),
  ];

  int get lagnaSign => zodiacSignIndex(chart.ascendant);
  int get munthaSign => munthaSignIndex(natalLagna, completedYears);
  int get munthaHouse => houseFrom(lagnaSign, munthaSign);
  MunthaTone get tone => munthaTone(munthaHouse);
  String get lagnaLord => DetectYogas.signLords[lagnaSign];
  String get munthaLord => DetectYogas.signLords[munthaSign];

  /// Annual-chart house of each planet, in the chart's planet order.
  List<(String planet, String sign, int house)> get placements => [
    for (final p in chart.planets)
      (p.planet, p.sign, houseFrom(lagnaSign, zodiacSignIndex(p.sign))),
  ];
}
