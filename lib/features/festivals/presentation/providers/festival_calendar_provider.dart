import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/current_location_provider.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../data/repositories/swiss_ephemeris_lunar_calendar_repository.dart';
import '../../domain/entities/calendar_observance.dart';
import '../../domain/repositories/lunar_calendar_repository.dart';
import '../../domain/usecases/build_festival_calendar.dart';

final lunarCalendarRepositoryProvider = Provider<LunarCalendarRepository>(
  (ref) => SwissEphemerisLunarCalendarRepository(),
);

/// "Today" for the calendar. Read once so the 12-month calculation is not
/// repeated every minute; overridable in tests.
final festivalTodayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Where festival dates are calculated for.
class FestivalPlace {
  final double latitude;
  final double longitude;
  final String timezone;

  /// City name when the place comes from the birth profile; `null` for the
  /// device's current location.
  final String? fallbackCity;

  const FestivalPlace({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    this.fallbackCity,
  });

  @override
  bool operator ==(Object other) =>
      other is FestivalPlace &&
      other.latitude.toStringAsFixed(2) == latitude.toStringAsFixed(2) &&
      other.longitude.toStringAsFixed(2) == longitude.toStringAsFixed(2) &&
      other.timezone == timezone;

  @override
  int get hashCode => Object.hash(
    latitude.toStringAsFixed(2),
    longitude.toStringAsFixed(2),
    timezone,
  );
}

/// Current device location, falling back to the active birth profile's
/// place when location is unavailable. `null` if neither exists.
final festivalPlaceProvider = FutureProvider<FestivalPlace?>((ref) async {
  final profile = ref.watch(birthProfileProvider);

  try {
    final current = await ref.watch(currentLocationProvider.future);
    if (current != null) {
      return FestivalPlace(
        latitude: current.latitude,
        longitude: current.longitude,
        timezone: current.timezone,
      );
    }
  } catch (_) {
    // Fall through to the birth profile.
  }

  if (profile == null) return null;
  return FestivalPlace(
    latitude: profile.location.latitude,
    longitude: profile.location.longitude,
    timezone: profile.location.timezone,
    fallbackCity: profile.location.city,
  );
});

class FestivalCalendar {
  final FestivalPlace place;
  final DateTime from;
  final DateTime to;
  final List<CalendarObservance> observances;

  const FestivalCalendar({
    required this.place,
    required this.from,
    required this.to,
    required this.observances,
  });

  List<CalendarObservance> inMonth(int year, int month) => observances
      .where((o) => o.date.year == year && o.date.month == month)
      .toList();

  List<CalendarObservance> upcoming(DateTime today, {bool majorOnly = false}) =>
      observances
          .where((o) => !o.date.isBefore(today))
          .where((o) => !majorOnly || o.id.isMajorFestival)
          .toList();
}

/// Twelve months of festivals and vrats starting with the current month.
final festivalCalendarProvider = FutureProvider<FestivalCalendar?>((ref) async {
  final today = ref.watch(festivalTodayProvider);
  final repository = ref.watch(lunarCalendarRepositoryProvider);
  final place = await ref.watch(festivalPlaceProvider.future);
  if (place == null) return null;

  final from = DateTime(today.year, today.month);
  final to = DateTime(today.year, today.month + 12, 0);

  final data = await repository.calculate(
    fromDate: from,
    toDate: to,
    latitude: place.latitude,
    longitude: place.longitude,
    timezone: place.timezone,
  );

  return FestivalCalendar(
    place: place,
    from: from,
    to: to,
    observances: const BuildFestivalCalendar()(
      data,
      fromDate: from,
      toDate: to,
    ),
  );
});

/// The next ~10 weeks only: what Home's next-festival card and the
/// evening reminders need. Much cheaper than the full-year calendar, so it
/// can run while the Today screen loads.
final upcomingFestivalsProvider = FutureProvider<FestivalCalendar?>((
  ref,
) async {
  final today = ref.watch(festivalTodayProvider);
  final repository = ref.watch(lunarCalendarRepositoryProvider);
  final place = await ref.watch(festivalPlaceProvider.future);
  if (place == null) return null;

  final to = DateTime(today.year, today.month, today.day + 75);

  final data = await repository.calculate(
    fromDate: today,
    toDate: to,
    latitude: place.latitude,
    longitude: place.longitude,
    timezone: place.timezone,
  );

  return FestivalCalendar(
    place: place,
    from: today,
    to: to,
    observances: const BuildFestivalCalendar()(
      data,
      fromDate: today,
      toDate: to,
    ),
  );
});
