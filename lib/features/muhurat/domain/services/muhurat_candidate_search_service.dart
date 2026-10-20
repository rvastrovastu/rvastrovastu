import '../../../panchang/domain/entities/daily_panchang.dart';
import '../../../panchang/domain/repositories/daily_panchang_repository.dart';

class MuhuratCandidate {
  final DateTime date;
  final DailyPanchang panchang;
  final String screeningReason;

  const MuhuratCandidate({
    required this.date,
    required this.panchang,
    required this.screeningReason,
  });
}

/// Screens sunrise Panchang samples for preliminary date candidates.
///
/// This is not a verified muhurat calculation. Exact tithi and nakshatra
/// boundaries, local auspicious time windows and other traditional factors
/// are not established by this screening.
class MuhuratCandidateSearchService {
  final DailyPanchangRepository repository;

  const MuhuratCandidateSearchService(this.repository);

  static const int searchDays = 30;

  static const Map<String, Set<String>> preferredNakshatras = {
    'marriage': {
      'Rohini',
      'Mrigashira',
      'Uttara Phalguni',
      'Hasta',
      'Swati',
      'Anuradha',
      'Uttara Ashadha',
      'Uttara Bhadrapada',
      'Revati',
    },
    'grihaPravesh': {
      'Rohini',
      'Mrigashira',
      'Chitra',
      'Anuradha',
      'Uttara Phalguni',
      'Uttara Ashadha',
      'Uttara Bhadrapada',
      'Revati',
    },
    'business': {
      'Ashwini',
      'Rohini',
      'Pushya',
      'Hasta',
      'Chitra',
      'Swati',
      'Anuradha',
      'Shravana',
      'Revati',
    },
    'vehicle': {
      'Ashwini',
      'Rohini',
      'Mrigashira',
      'Hasta',
      'Swati',
      'Anuradha',
      'Shravana',
      'Dhanishta',
      'Revati',
    },
    'travel': {
      'Ashwini',
      'Mrigashira',
      'Punarvasu',
      'Pushya',
      'Hasta',
      'Anuradha',
      'Shravana',
      'Dhanishta',
      'Revati',
    },
  };

  Future<List<MuhuratCandidate>> search({
    required String purpose,
    required DateTime startDate,
    required double latitude,
    required double longitude,
    required String timezone,
  }) async {
    final preferred = preferredNakshatras[purpose];
    if (preferred == null) {
      throw ArgumentError.value(purpose, 'purpose', 'Unsupported event type');
    }

    final firstDay = DateTime(startDate.year, startDate.month, startDate.day);
    final candidates = <MuhuratCandidate>[];

    for (var offset = 0; offset < searchDays; offset++) {
      final date = DateTime(
        firstDay.year,
        firstDay.month,
        firstDay.day + offset,
      );
      final panchang = await repository.calculate(
        date: date,
        latitude: latitude,
        longitude: longitude,
        timezone: timezone,
      );

      final tithi = panchang.tithi.trim();
      final nakshatra = panchang.nakshatra.trim();
      final yoga = panchang.yoga.trim();

      // Skip missing Panchang values, including days without sunrise.
      if (tithi.isEmpty ||
          nakshatra.isEmpty ||
          yoga.isEmpty ||
          tithi == '—' ||
          nakshatra == '—' ||
          yoga == '—') {
        continue;
      }

      final normalizedTithi = tithi.toLowerCase();
      final normalizedYoga = yoga.toLowerCase();

      // Preliminary exclusions only; not a complete Panchang assessment.
      if (normalizedTithi.contains('amavasya') ||
          normalizedTithi.contains('chaturdashi') ||
          normalizedTithi.contains('ashtami') ||
          normalizedTithi.contains('navami')) {
        continue;
      }

      if (normalizedYoga.contains('vyatipata') ||
          normalizedYoga.contains('vaidhriti')) {
        continue;
      }

      final matchingNakshatra = preferred.any(
        (name) => nakshatra.toLowerCase().contains(name.toLowerCase()),
      );
      if (!matchingNakshatra) continue;

      final activity = switch (purpose) {
        'marriage' => 'marriage ceremonies',
        'grihaPravesh' => 'Griha Pravesh and housewarming',
        'business' => 'business openings and beginnings',
        'vehicle' => 'vehicle purchase or delivery',
        'travel' => 'starting a journey',
        _ => 'this activity',
      };

      candidates.add(
        MuhuratCandidate(
          date: date,
          panchang: panchang,
          screeningReason:
              '$nakshatra is in the preferred nakshatra set for '
              '$activity. The sunrise Panchang sample passed the app\'s '
              'preliminary tithi and yoga exclusions.',
        ),
      );
    }

    return candidates;
  }
}
