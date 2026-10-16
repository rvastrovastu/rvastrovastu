import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/muhurat/domain/services/muhurat_candidate_search_service.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/daily_panchang.dart';
import 'package:rv_astro_vastu/features/panchang/domain/repositories/daily_panchang_repository.dart';

class _FakePanchangRepository implements DailyPanchangRepository {
  _FakePanchangRepository({
    this.tithi = 'Shukla Panchami',
    this.nakshatra = 'Rohini',
    this.yoga = 'Siddha',
  });

  final String tithi;
  final String nakshatra;
  final String yoga;
  final List<DateTime> requestedDates = [];

  @override
  Future<DailyPanchang> calculate({
    required DateTime date,
    required double latitude,
    required double longitude,
    required String timezone,
  }) async {
    requestedDates.add(date);
    return DailyPanchang(
      date: date,
      tithi: tithi,
      nakshatra: nakshatra,
      yoga: yoga,
      sunrise: '06:59 AM',
      sunset: '07:55 PM',
      moonrise: '08:43 PM',
      rahuKaal: '09:00 AM – 10:30 AM',
      muhurat: '11:45 AM – 12:30 PM',
    );
  }
}

void main() {
  final startDate = DateTime(2026, 10, 15);

  Future<List<MuhuratCandidate>> search(
    _FakePanchangRepository repository, {
    required String purpose,
  }) {
    return MuhuratCandidateSearchService(repository).search(
      purpose: purpose,
      startDate: startDate,
      latitude: 32.95,
      longitude: -96.80,
      timezone: 'America/Chicago',
    );
  }

  group('MuhuratCandidateSearchService', () {
    for (final purpose in [
      'marriage',
      'grihaPravesh',
      'business',
      'vehicle',
      'travel',
    ]) {
      test('finds preliminary candidates for $purpose', () async {
        final expectedNakshatra = purpose == 'travel' ? 'Ashwini' : 'Rohini';
        final repository = _FakePanchangRepository(
          nakshatra: expectedNakshatra,
        );

        final results = await search(repository, purpose: purpose);

        expect(results, isNotEmpty);
        expect(results, hasLength(30));
        expect(repository.requestedDates, hasLength(30));
        expect(results.first.date, startDate);
        expect(results.last.date.year, 2026);
        expect(results.last.date.month, 11);
        expect(results.last.date.day, 13);
        expect(results.first.panchang.nakshatra, expectedNakshatra);
        expect(results.first.screeningReason, isNotEmpty);
      });
    }

    test('skips excluded tithis', () async {
      for (final tithi in [
        'Amavasya',
        'Krishna Chaturdashi',
        'Krishna Ashtami',
        'Shukla Navami',
      ]) {
        final repository = _FakePanchangRepository(tithi: tithi);
        final results = await search(repository, purpose: 'marriage');
        expect(results, isEmpty, reason: 'Should exclude $tithi');
      }
    });

    test('skips excluded yogas', () async {
      for (final yoga in ['Vyatipata', 'Vaidhriti']) {
        final repository = _FakePanchangRepository(yoga: yoga);
        final results = await search(repository, purpose: 'marriage');
        expect(results, isEmpty, reason: 'Should exclude $yoga');
      }
    });

    test('skips incomplete Panchang values', () async {
      for (final values in [
        ('—', 'Rohini', 'Siddha'),
        ('Shukla Panchami', '—', 'Siddha'),
        ('Shukla Panchami', 'Rohini', '—'),
        ('', 'Rohini', 'Siddha'),
      ]) {
        final repository = _FakePanchangRepository(
          tithi: values.$1,
          nakshatra: values.$2,
          yoga: values.$3,
        );

        final results = await search(repository, purpose: 'marriage');
        expect(results, isEmpty);
      }
    });

    test('returns no candidates when no preferred nakshatra matches', () async {
      final repository = _FakePanchangRepository(nakshatra: 'Bharani');

      final results = await search(repository, purpose: 'marriage');

      expect(results, isEmpty);
      expect(repository.requestedDates, hasLength(30));
    });

    test('rejects unsupported purposes', () async {
      final repository = _FakePanchangRepository();

      await expectLater(
        search(repository, purpose: 'general'),
        throwsArgumentError,
      );
      expect(repository.requestedDates, isEmpty);
    });
  });
}
