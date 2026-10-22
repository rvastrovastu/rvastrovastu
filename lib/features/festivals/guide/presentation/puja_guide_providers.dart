import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../panchang/domain/entities/daily_panchang_input.dart';
import '../../../panchang/presentation/providers/daily_panchang_provider.dart';
import '../../../panchang/presentation/providers/day_divisions_provider.dart';
import '../../domain/entities/calendar_observance.dart';
import '../../presentation/providers/festival_calendar_provider.dart';
import '../data/puja_guide_repository.dart';
import '../domain/puja_guide.dart';
import '../domain/puja_timing.dart';

final pujaGuideRepositoryProvider = Provider<PujaGuideRepository>(
  (ref) => PujaGuideRepository(),
);

/// Every observance's guide in the language for this language code.
final pujaGuidesProvider =
    FutureProvider.family<Map<ObservanceId, PujaGuide>, String>(
      (ref, languageCode) =>
          ref.watch(pujaGuideRepositoryProvider).guides(languageCode),
    );

final aartiLibraryProvider = FutureProvider<Map<String, Aarti>>(
  (ref) => ref.watch(pujaGuideRepositoryProvider).aartis(),
);

/// When to do an observance's puja on a given date, at the place the
/// festival calendar uses.
class PujaTiming {
  final PujaTimeRule rule;
  final String timezone;

  /// Birth-profile city when the phone's location isn't used.
  final String? city;

  /// Null for moonrise observances, or where the Sun doesn't rise.
  final TimeWindow? window;

  /// Moonrise as shown in the Panchang, for moonrise observances.
  final String? moonrise;

  /// Rahu Kaal, Yamaganda and Gulika on that day.
  final List<(String, TimeWindow)> avoid;

  const PujaTiming({
    required this.rule,
    required this.timezone,
    this.city,
    this.window,
    this.moonrise,
    this.avoid = const [],
  });

  /// The periods to avoid that fall inside the puja window.
  List<String> get clashes {
    final w = window;
    if (w == null) return const [];
    return [
      for (final (key, period) in avoid)
        if (period.overlaps(w)) key,
    ];
  }
}

typedef PujaTimingKey = ({ObservanceId id, DateTime date});

final pujaTimingProvider = FutureProvider.family<PujaTiming?, PujaTimingKey>((
  ref,
  key,
) async {
  final place = await ref.watch(festivalPlaceProvider.future);
  if (place == null) return null;

  final input = DailyPanchangInput(
    date: DateTime(key.date.year, key.date.month, key.date.day),
    latitude: place.latitude,
    longitude: place.longitude,
    timezone: place.timezone,
  );
  final rule = pujaTimeRuleFor(key.id);
  final day = (await ref.watch(dayDivisionsProvider(input).future)).today;
  final moonrise = rule == PujaTimeRule.moonrise
      ? (await ref.watch(dailyPanchangProvider(input).future)).moonrise
      : null;

  return PujaTiming(
    rule: rule,
    timezone: place.timezone,
    city: place.fallbackCity,
    window: day == null ? null : pujaWindow(rule, day.sun),
    moonrise: moonrise,
    avoid: day == null ? const [] : periodsToAvoid(day),
  );
});
