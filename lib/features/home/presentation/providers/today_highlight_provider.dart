import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../festivals/domain/entities/calendar_observance.dart';
import '../../../horoscope/domain/entities/daily_horoscope.dart';
import '../../../festivals/presentation/providers/festival_calendar_provider.dart';
import '../../../horoscope/presentation/providers/daily_horoscope_provider.dart';
import '../../../your_day/data/swiss_ephemeris_moon_repository.dart';
import '../../../your_day/domain/day_strength.dart';
import '../../../your_day/presentation/your_day_provider.dart';
import '../../../../core/location/current_location_provider.dart';
import '../../../panchang/domain/entities/daily_panchang.dart';
import '../../../panchang/domain/entities/daily_panchang_input.dart';
import '../../../panchang/presentation/providers/daily_panchang_provider.dart';

enum HighlightKind { festival, eclipse, sankranti, personal }

/// The one event shown at the top of Today.
class TodayHighlight {
  final HighlightKind kind;
  final ObservanceId? observance;
  final DateTime? observanceDate;
  final List<AreaReading> areas;
  final EclipseHit? eclipse;
  final int? signIndex;
  final String? tithi;
  final String? nakshatra;
  final String headlineKey;
  final DayVerdict? verdict;

  const TodayHighlight({
    required this.kind,
    required this.headlineKey,
    this.observance,
    this.observanceDate,
    this.areas = const [],
    this.eclipse,
    this.signIndex,
    this.tithi,
    this.nakshatra,
    this.verdict,
  });
}

/// An eclipse on [day] (local date), or null.
final eclipseOnProvider =
    FutureProvider.autoDispose.family<EclipseHit?, DateTime>((ref, day) async {
      final start = DateTime(day.year, day.month, day.day);
      final end = DateTime(day.year, day.month, day.day + 1);
      try {
        return await ref.watch(moonRepositoryProvider).eclipseBetween(start, end);
      } catch (error) {
        debugPrint('[TODAY] eclipse check failed: $error');
        return null;
      }
    });

/// How much an observance matters on its own; eclipses score 88.
int _festivalScore(ObservanceId id) {
  if (id.isMajorFestival) return 90;
  return switch (id.category) {
    ObservanceCategory.fullNewMoon => 75,
    ObservanceCategory.ekadashi => 70,
    ObservanceCategory.vrat => 55,
    ObservanceCategory.festival => 90,
  };
}

const _eclipseScore = 88;
const _sankrantiScore = 85;
const _personalScore = 40;

/// The sign the Sun enters on [day] (local date), or null.
final sunEntersSignOnProvider =
    FutureProvider.autoDispose.family<int?, DateTime>((ref, day) async {
      final start = DateTime(day.year, day.month, day.day);
      final end = DateTime(day.year, day.month, day.day + 1);
      try {
        return await ref
            .watch(moonRepositoryProvider)
            .sunEntersSignBetween(start, end);
      } catch (error) {
        debugPrint('[TODAY] sankranti check failed: $error');
        return null;
      }
    });

/// Today's single most important item: a festival, an eclipse, or the
/// personal reading when nothing else applies.
/// Today's Panchang (tithi and nakshatra) for the user's location.
final todayPanchangProvider = FutureProvider.autoDispose<DailyPanchang?>((
  ref,
) async {
  final location = await ref.watch(currentLocationProvider.future);
  if (location == null) return null;
  final today = ref.watch(festivalTodayProvider);
  try {
    return await ref.watch(
      dailyPanchangProvider(
        DailyPanchangInput(
          date: today,
          latitude: location.latitude,
          longitude: location.longitude,
          timezone: location.timezone,
        ),
      ).future,
    );
  } catch (error) {
    debugPrint('[TODAY] panchang for highlight failed: $error');
    return null;
  }
});

final todayHighlightProvider = FutureProvider.autoDispose<TodayHighlight?>((
  ref,
) async {
  final today = ref.watch(festivalTodayProvider);
  final horoscope = await ref.watch(dailyHoroscopeProvider.future);
  final calendar = await ref.watch(upcomingFestivalsProvider.future);
  final eclipse = await ref.watch(eclipseOnProvider(today).future);
  final sign = await ref.watch(sunEntersSignOnProvider(today).future);
  final panchang = await ref.watch(todayPanchangProvider.future);

  final todays = (calendar?.upcoming(today) ?? const <CalendarObservance>[])
      .where(
        (o) =>
            o.date.year == today.year &&
            o.date.month == today.month &&
            o.date.day == today.day,
      )
      .toList();

  // Candidates with their scores; the highest wins.
  final candidates = <(int, TodayHighlight)>[];
  for (final o in todays) {
    candidates.add((
      _festivalScore(o.id),
      TodayHighlight(
        kind: HighlightKind.festival,
        observance: o.id,
        observanceDate: o.date,
        headlineKey: horoscope?.headlineKey ?? 'other',
        verdict: horoscope?.verdict,
        areas: horoscope?.areas ?? const [],
      ),
    ));
  }
  if (eclipse != null) {
    candidates.add((
      _eclipseScore,
      TodayHighlight(
        kind: HighlightKind.eclipse,
        eclipse: eclipse,
        headlineKey: horoscope?.headlineKey ?? 'other',
        verdict: horoscope?.verdict,
        areas: horoscope?.areas ?? const [],
      ),
    ));
  }
  if (sign != null) {
    candidates.add((
      _sankrantiScore,
      TodayHighlight(
        kind: HighlightKind.sankranti,
        signIndex: sign,
        headlineKey: horoscope?.headlineKey ?? 'other',
        verdict: horoscope?.verdict,
        areas: horoscope?.areas ?? const [],
      ),
    ));
  }
  if (horoscope != null || panchang != null) {
    candidates.add((
      _personalScore,
      TodayHighlight(
        kind: HighlightKind.personal,
        headlineKey: horoscope?.headlineKey ?? 'other',
        verdict: horoscope?.verdict,
        areas: horoscope?.areas ?? const [],
        tithi: panchang?.tithi,
        nakshatra: panchang?.nakshatra,
      ),
    ));
  }
  if (candidates.isEmpty) return null;

  candidates.sort((a, b) => b.$1.compareTo(a.$1));
  return candidates.first.$2;
});
