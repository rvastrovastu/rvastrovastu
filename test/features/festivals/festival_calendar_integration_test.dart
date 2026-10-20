import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/festivals/data/repositories/swiss_ephemeris_lunar_calendar_repository.dart';
import 'package:rv_astro_vastu/features/festivals/domain/entities/calendar_observance.dart';
import 'package:rv_astro_vastu/features/festivals/domain/usecases/build_festival_calendar.dart';
import 'package:timezone/data/latest.dart' as tz;

/// End-to-end check with real Swiss Ephemeris data against published 2026
/// festival dates. Expected values were also reproduced independently in
/// Python (pyswisseph) with the same rules.
void main() {
  setUpAll(tz.initializeTimeZones);

  Future<Map<ObservanceId, DateTime>> majorFestivals2026({
    required double latitude,
    required double longitude,
    required String timezone,
  }) async {
    final from = DateTime(2026);
    final to = DateTime(2026, 12, 31);
    final data = await SwissEphemerisLunarCalendarRepository().calculate(
      fromDate: from,
      toDate: to,
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
    );
    final observances = const BuildFestivalCalendar()(
      data,
      fromDate: from,
      toDate: to,
    );
    return {
      for (final o in observances)
        if (o.id.category == ObservanceCategory.festival ||
            o.id.isMajorFestival)
          o.id: o.date,
    };
  }

  test('Delhi 2026 major festivals', () async {
    final dates = await majorFestivals2026(
      latitude: 28.6139,
      longitude: 77.209,
      timezone: 'Asia/Kolkata',
    );

    expect(dates[ObservanceId.makarSankranti], DateTime(2026, 1, 14));
    expect(dates[ObservanceId.vasantPanchami], DateTime(2026, 1, 23));
    expect(dates[ObservanceId.mahaShivaratri], DateTime(2026, 2, 15));
    expect(dates[ObservanceId.holi], DateTime(2026, 3, 4));
    expect(dates[ObservanceId.ugadi], DateTime(2026, 3, 19));
    expect(dates[ObservanceId.ramNavami], DateTime(2026, 3, 26));
    expect(dates[ObservanceId.nirjalaEkadashi], DateTime(2026, 6, 25));
    expect(dates[ObservanceId.guruPurnima], DateTime(2026, 7, 29));
    expect(dates[ObservanceId.rakshaBandhan], DateTime(2026, 8, 28));
    expect(dates[ObservanceId.janmashtami], DateTime(2026, 9, 4));
    expect(dates[ObservanceId.ganeshChaturthi], DateTime(2026, 9, 14));
    expect(dates[ObservanceId.navratri], DateTime(2026, 10, 11));
    expect(dates[ObservanceId.dussehra], DateTime(2026, 10, 20));
    expect(dates[ObservanceId.karvaChauth], DateTime(2026, 10, 29));
    expect(dates[ObservanceId.dhanteras], DateTime(2026, 11, 6));
    expect(dates[ObservanceId.diwali], DateTime(2026, 11, 8));
    expect(dates[ObservanceId.devUthaniEkadashi], DateTime(2026, 11, 20));
  });

  test('Dallas 2026 dates shift where the tithi changes overnight', () async {
    final dates = await majorFestivals2026(
      latitude: 32.7767,
      longitude: -96.797,
      timezone: 'America/Chicago',
    );

    expect(dates[ObservanceId.holi], DateTime(2026, 3, 3));
    expect(dates[ObservanceId.rakshaBandhan], DateTime(2026, 8, 27));
    expect(dates[ObservanceId.janmashtami], DateTime(2026, 9, 3));
    expect(dates[ObservanceId.karvaChauth], DateTime(2026, 10, 28));
    expect(dates[ObservanceId.diwali], DateTime(2026, 11, 8));
  });

  test('2026 Adhik Jyeshtha does not produce duplicate festivals', () async {
    final data = await SwissEphemerisLunarCalendarRepository().calculate(
      fromDate: DateTime(2026, 5),
      toDate: DateTime(2026, 7, 31),
      latitude: 28.6139,
      longitude: 77.209,
      timezone: 'Asia/Kolkata',
    );
    final observances = const BuildFestivalCalendar()(
      data,
      fromDate: DateTime(2026, 5),
      toDate: DateTime(2026, 7, 31),
    );

    final nirjala = observances
        .where((o) => o.id == ObservanceId.nirjalaEkadashi)
        .toList();
    expect(nirjala, hasLength(1));
    expect(nirjala.single.date, DateTime(2026, 6, 25));
  });
}
