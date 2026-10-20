import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/domain/entities/planet_position.dart';
import '../../../dasha/domain/entities/dasha_period.dart';
import '../entities/daily_horoscope.dart';

class GenerateDailyHoroscope {
  DailyHoroscope call({
    required Kundali kundali,
    required DashaPeriod? mahadasha,
    required DashaPeriod? antardasha,
    required DateTime date,
  }) {
    final planets = kundali.planets;

    final mercury = _planet(planets, 'Mercury');
    final venus = _planet(planets, 'Venus');
    final jupiter = _planet(planets, 'Jupiter');
    final saturn = _planet(planets, 'Saturn');
    final moon = _planet(planets, 'Moon');

    final hasRetrograde = planets.any((planet) => planet.retrograde);

    final mahadashaName = mahadasha?.planet.name ?? 'Unknown';
    final antardashaName = antardasha?.planet.name ?? 'Unknown';

    return DailyHoroscope(
      date: date,
      career: _career(
        mahadasha: mahadashaName,
        antardasha: antardashaName,
        mercury: mercury,
        jupiter: jupiter,
        saturn: saturn,
        hasRetrograde: hasRetrograde,
      ),
      finance: _finance(
        mahadasha: mahadashaName,
        antardasha: antardashaName,
        venus: venus,
        jupiter: jupiter,
        saturn: saturn,
      ),
      relationships: _relationships(
        nakshatra: kundali.nakshatra,
        venus: venus,
        moon: moon,
      ),
      careerKey: _careerKey(
        mercury: mercury,
        jupiter: jupiter,
        saturn: saturn,
        hasRetrograde: hasRetrograde,
      ),
      financeKey: _financeKey(venus: venus, jupiter: jupiter, saturn: saturn),
      relationshipsKey: _relationshipsKey(venus: venus, moon: moon),
      mahadasha: mahadashaName,
      antardasha: antardashaName,
      nakshatra: kundali.nakshatra,
    );
  }

  String _career({
    required String mahadasha,
    required String antardasha,
    required PlanetPosition? mercury,
    required PlanetPosition? jupiter,
    required PlanetPosition? saturn,
    required bool hasRetrograde,
  }) {
    if (mercury != null && mercury.house == 10) {
      return 'Career favors communication, analysis and focused execution. '
          'Use your Mercury influence to organize priorities and turn ideas '
          'into measurable progress.';
    }

    if (jupiter != null && (jupiter.house == 9 || jupiter.house == 10)) {
      return 'Professional growth is supported through learning, guidance '
          'and long-term decisions. Stay open to opportunities that expand '
          'your responsibilities or expertise.';
    }

    if (saturn != null && (saturn.house == 10 || saturn.house == 11)) {
      return 'Steady effort is more valuable than quick results today. '
          'Take responsibility for important tasks and build progress '
          'through disciplined execution.';
    }

    if (hasRetrograde) {
      return 'Review ongoing work before pushing ahead. A thoughtful second '
          'look at communication, commitments and unfinished tasks can '
          'prevent avoidable delays.';
    }

    return 'Focus on clear priorities and consistent execution. Your '
        '$mahadasha–$antardasha period favors deliberate decisions rather '
        'than unnecessary distractions.';
  }

  String _finance({
    required String mahadasha,
    required String antardasha,
    required PlanetPosition? venus,
    required PlanetPosition? jupiter,
    required PlanetPosition? saturn,
  }) {
    if (jupiter != null && (jupiter.house == 2 || jupiter.house == 11)) {
      return 'Financial prospects benefit from practical planning and '
          'long-term thinking. Review opportunities carefully before '
          'committing funds.';
    }

    if (venus != null && (venus.house == 2 || venus.house == 11)) {
      return 'Financial decisions can benefit from balance and moderation. '
          'Prioritize useful purchases and avoid spending simply for '
          'short-term comfort.';
    }

    if (saturn != null && (saturn.house == 2 || saturn.house == 11)) {
      return 'Financial discipline is especially important. Review budgets, '
          'recurring expenses and commitments before making new decisions.';
    }

    return 'Keep financial decisions measured and practical. The '
        '$mahadasha–$antardasha period favors reviewing priorities and '
        'avoiding unnecessary risk.';
  }

  String _relationships({
    required String nakshatra,
    required PlanetPosition? venus,
    required PlanetPosition? moon,
  }) {
    if (venus != null && (venus.house == 5 || venus.house == 7)) {
      return 'Warmth and openness can strengthen relationships today. '
          'Make time for meaningful conversation and allow appreciation to '
          'be expressed clearly.';
    }

    if (moon != null && moon.house == 4) {
      return 'Emotional connection and a supportive home environment are '
          'important today. Gentle communication can create greater '
          'understanding with loved ones.';
    }

    return 'Patience and clear communication can improve relationships. '
        'Your $nakshatra influence suggests paying attention to emotional '
        'signals rather than reacting too quickly.';
  }

  String _careerKey({
    required PlanetPosition? mercury,
    required PlanetPosition? jupiter,
    required PlanetPosition? saturn,
    required bool hasRetrograde,
  }) {
    if (mercury != null && mercury.house == 10) {
      return 'mercury';
    }

    if (jupiter != null && (jupiter.house == 9 || jupiter.house == 10)) {
      return 'jupiter';
    }

    if (saturn != null && (saturn.house == 10 || saturn.house == 11)) {
      return 'saturn';
    }

    if (hasRetrograde) {
      return 'retrograde';
    }

    return 'general';
  }

  String _financeKey({
    required PlanetPosition? venus,
    required PlanetPosition? jupiter,
    required PlanetPosition? saturn,
  }) {
    if (jupiter != null && (jupiter.house == 2 || jupiter.house == 11)) {
      return 'jupiter';
    }

    if (venus != null && (venus.house == 2 || venus.house == 11)) {
      return 'venus';
    }

    if (saturn != null && (saturn.house == 2 || saturn.house == 11)) {
      return 'saturn';
    }

    return 'general';
  }

  String _relationshipsKey({
    required PlanetPosition? venus,
    required PlanetPosition? moon,
  }) {
    if (venus != null && (venus.house == 5 || venus.house == 7)) {
      return 'venus';
    }

    if (moon != null && moon.house == 4) {
      return 'moon';
    }

    return 'general';
  }

  PlanetPosition? _planet(List<PlanetPosition> planets, String name) {
    for (final planet in planets) {
      if (planet.planet == name) {
        return planet;
      }
    }

    return null;
  }
}
