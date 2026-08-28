class DailyDashboard {
  final DateTime date;

  // Cosmic snapshot
  final String rashi;
  final String tithi;
  final String nakshatra;
  final String yoga;

  // Dasha
  final String mahadasha;
  final String antardasha;

  // Panchang timing
  final String sunrise;
  final String sunset;
  final String muhurat;
  final String rahuKaal;

  // Personalized guidance
  final String overallGuidance;
  final String careerGuidance;
  final String financeGuidance;
  final String relationshipGuidance;

  final List<String> favorableActivities;
  final List<String> cautionAreas;
  final List<String> remedies;
  final List<String> upcomingEvents;

  const DailyDashboard({
    required this.date,
    this.rashi = '',
    required this.tithi,
    required this.nakshatra,
    this.yoga = '',
    required this.mahadasha,
    required this.antardasha,
    this.sunrise = '',
    this.sunset = '',
    this.muhurat = '',
    this.rahuKaal = '',
    required this.overallGuidance,
    this.careerGuidance = '',
    this.financeGuidance = '',
    this.relationshipGuidance = '',
    required this.favorableActivities,
    required this.cautionAreas,
    required this.remedies,
    required this.upcomingEvents,
  });
}
