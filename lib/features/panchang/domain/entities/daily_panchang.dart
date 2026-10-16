class DailyPanchang {
  final DateTime date;
  final String tithi;
  final String nakshatra;
  final String yoga;
  final String sunrise;
  final String sunset;
  final String moonrise;
  final String rahuKaal;
  final String muhurat;

  const DailyPanchang({
    required this.date,
    required this.tithi,
    required this.nakshatra,
    required this.yoga,
    required this.sunrise,
    required this.sunset,
    required this.moonrise,
    required this.rahuKaal,
    required this.muhurat,
  });
}
