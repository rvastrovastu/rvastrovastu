import '../entities/daily_dashboard.dart';

class GetDailyDashboard {
  const GetDailyDashboard();

  DailyDashboard execute({
    required DateTime date,
    required String tithi,
    required String nakshatra,
    required String mahadasha,
    required String antardasha,
    String rashi = '',
    String yoga = '',
    String sunrise = '',
    String sunset = '',
    String muhurat = '',
    String rahuKaal = '',
  }) {
    return DailyDashboard(
      date: date,
      rashi: rashi,
      tithi: tithi,
      nakshatra: nakshatra,
      yoga: yoga,
      mahadasha: mahadasha,
      antardasha: antardasha,
      sunrise: sunrise,
      sunset: sunset,
      muhurat: muhurat,
      rahuKaal: rahuKaal,
      overallGuidance:
          'Use the day thoughtfully and focus on activities aligned with your current planetary period.',
      careerGuidance:
          'Focus on priorities, thoughtful communication and consistent execution.',
      financeGuidance:
          'Review important financial decisions carefully and avoid unnecessary impulsive commitments.',
      relationshipGuidance:
          'Patient communication and understanding can strengthen important relationships today.',
      favorableActivities: const [
        'Planning',
        'Learning',
        'Important conversations',
      ],
      cautionAreas: const ['Avoid unnecessary impulsive decisions'],
      remedies: const ['Maintain a calm and focused routine'],
      upcomingEvents: const [],
    );
  }
}
