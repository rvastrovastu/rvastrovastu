import '../entities/dasha_insight.dart';
import '../entities/dasha_period.dart';

class GenerateDashaInsight {
  DashaInsight call({
    required DashaPeriod? mahadasha,
    required DashaPeriod? antardasha,
  }) {
    if (mahadasha == null) {
      return const DashaInsight(
        mahadasha: null,
        antardasha: null,
        focus: 'Your current Dasha period is not available.',
        career: 'Complete your birth profile to calculate your current Dasha.',
        finance: 'Complete your birth profile to calculate your current Dasha.',
        relationships:
            'Complete your birth profile to calculate your current Dasha.',
      );
    }

    final validAntardasha =
        antardasha != null &&
            antardasha.level == 2 &&
            antardasha.startDate.compareTo(mahadasha.startDate) >= 0 &&
            antardasha.endDate.compareTo(mahadasha.endDate) <= 0 &&
            antardasha.startDate.isBefore(antardasha.endDate)
        ? antardasha
        : null;

    final maha = mahadasha.planet;
    final antara = validAntardasha?.planet;

    return DashaInsight(
      mahadasha: mahadasha,
      antardasha: validAntardasha,
      focus: _focus(maha, antara),
      career: _career(maha, antara),
      finance: _finance(maha, antara),
      relationships: _relationships(maha, antara),
    );
  }

  String _focus(DashaPlanet maha, DashaPlanet? antara) {
    if (antara == null) {
      return '${maha.name} Mahadasha emphasizes the themes associated '
          'with ${maha.name}. Stay focused on deliberate, long-term progress.';
    }

    return '${maha.name} Mahadasha with ${antara.name} Antardasha '
        'highlights a period of focused action, decisions and personal growth.';
  }

  String _career(DashaPlanet maha, DashaPlanet? antara) {
    switch (maha) {
      case DashaPlanet.sun:
        return 'Leadership, visibility and responsibility are important '
            'career themes. Take ownership of decisions and show confidence.';
      case DashaPlanet.moon:
        return 'Career benefits from adaptability, people skills and '
            'attention to changing circumstances. Avoid reacting impulsively.';
      case DashaPlanet.mars:
        return 'Initiative and decisive action are favored. Channel energy '
            'into productive execution rather than unnecessary conflict.';
      case DashaPlanet.rahu:
        return 'Innovation, technology and unconventional opportunities may '
            'be significant. Evaluate ambitious moves carefully before acting.';
      case DashaPlanet.jupiter:
        return 'Growth through learning, guidance and strategic decisions is '
            'favored. Think beyond immediate results.';
      case DashaPlanet.saturn:
        return 'Discipline, responsibility and consistent effort are central. '
            'Build durable results rather than chasing quick wins.';
      case DashaPlanet.mercury:
        return 'Communication, analysis, business and learning are emphasized. '
            'Use clear thinking and organized execution.';
      case DashaPlanet.ketu:
        return 'Simplify priorities and avoid distractions. Focus on meaningful '
            'work and review whether current goals remain relevant.';
      case DashaPlanet.venus:
        return 'Relationships, creativity, negotiation and value creation can '
            'support professional growth. Maintain balance in commitments.';
    }
  }

  String _finance(DashaPlanet maha, DashaPlanet? antara) {
    switch (maha) {
      case DashaPlanet.sun:
        return 'Keep financial decisions structured and avoid unnecessary '
            'status-driven spending.';
      case DashaPlanet.moon:
        return 'Maintain a flexible budget and avoid making financial choices '
            'based mainly on changing emotions.';
      case DashaPlanet.mars:
        return 'Control impulsive spending and prioritize planned investments '
            'over rushed financial decisions.';
      case DashaPlanet.rahu:
        return 'Be especially careful with speculative opportunities. Verify '
            'details and risk before committing funds.';
      case DashaPlanet.jupiter:
        return 'Long-term financial planning and measured growth are favored. '
            'Review opportunities with a broad perspective.';
      case DashaPlanet.saturn:
        return 'Financial discipline is important. Review recurring expenses, '
            'obligations and long-term commitments.';
      case DashaPlanet.mercury:
        return 'Planning, negotiation and careful analysis can improve financial '
            'decisions. Review numbers before committing.';
      case DashaPlanet.ketu:
        return 'Avoid unnecessary financial complexity. Simplify commitments '
            'and focus on essential priorities.';
      case DashaPlanet.venus:
        return 'Balance comfort and financial discipline. Favor useful value '
            'over unnecessary luxury or impulse spending.';
    }
  }

  String _relationships(DashaPlanet maha, DashaPlanet? antara) {
    switch (maha) {
      case DashaPlanet.sun:
        return 'Respect and mutual recognition matter in relationships. '
            'Practice confidence without becoming overly rigid.';
      case DashaPlanet.moon:
        return 'Emotional understanding is important. Give yourself and others '
            'space to express feelings clearly.';
      case DashaPlanet.mars:
        return 'Use patience when emotions run high. Direct energy toward '
            'constructive communication rather than arguments.';
      case DashaPlanet.rahu:
        return 'Avoid assumptions and unclear expectations. Honest communication '
            'can reduce unnecessary confusion.';
      case DashaPlanet.jupiter:
        return 'Support, wisdom and generosity can strengthen relationships. '
            'Make time for meaningful conversations.';
      case DashaPlanet.saturn:
        return 'Consistency and responsibility strengthen relationships. '
            'Be patient and dependable with people who matter.';
      case DashaPlanet.mercury:
        return 'Clear communication is especially valuable. Talk through '
            'important matters rather than relying on assumptions.';
      case DashaPlanet.ketu:
        return 'Give relationships thoughtful attention even if you feel '
            'withdrawn. Avoid unnecessary emotional distance.';
      case DashaPlanet.venus:
        return 'Warmth, appreciation and shared experiences can strengthen '
            'relationships. Make time for connection.';
    }
  }
}
