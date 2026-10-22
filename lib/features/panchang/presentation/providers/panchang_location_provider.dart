import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/location/current_location.dart';
import '../../../../core/location/current_location_provider.dart';
import '../../../../core/location/device_time_zone.dart';
import '../../../birth_profile/data/models/birth_profile_model.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';

/// Where a place for timings came from, best first.
enum PlaceSource {
  /// The phone's GPS.
  gps,

  /// The principal city of the phone's time zone setting.
  timeZone,

  /// The active birth profile's city.
  profile,
}

/// Where Panchang timings are calculated for.
class PanchangPlace {
  final CurrentLocation location;
  final PlaceSource source;

  const PanchangPlace(this.location, {this.source = PlaceSource.gps});

  /// True when GPS isn't available and an approximate place is used.
  bool get isFallback => source != PlaceSource.gps;
}

/// The phone's location when GPS answers. Otherwise a place in the
/// phone's time zone: the birth-profile city if it is in that zone, or
/// else the zone's principal city, so dates and times always follow the
/// clock the user lives by. The birth-profile city is used only when the
/// time zone can't be read.
PanchangPlace? resolvePanchangPlace({
  CurrentLocation? live,
  String? deviceZone,
  BirthProfileModel? profile,
}) {
  if (live != null) return PanchangPlace(live);

  final profilePlace =
      profile == null || profile.location.timezone.trim().isEmpty
      ? null
      : CurrentLocation(
          latitude: profile.location.latitude,
          longitude: profile.location.longitude,
          timezone: profile.location.timezone,
          city: profile.location.city,
        );

  if (deviceZone != null) {
    if (profilePlace != null && sameZone(profilePlace.timezone, deviceZone)) {
      return PanchangPlace(profilePlace, source: PlaceSource.profile);
    }
    if (timeZonePlace(deviceZone) case final zonePlace?) {
      return PanchangPlace(zonePlace, source: PlaceSource.timeZone);
    }
  }

  if (profilePlace != null) {
    return PanchangPlace(profilePlace, source: PlaceSource.profile);
  }
  return null;
}

/// Shared by Today, Daily Timing and the Muhurat planner so they always
/// agree. See [resolvePanchangPlace].
final panchangPlaceProvider = Provider<AsyncValue<PanchangPlace?>>((ref) {
  final live = ref.watch(currentLocationProvider);
  if (live.value case final location?) return AsyncData(PanchangPlace(location));

  // Reading the time zone takes a moment; wait for it rather than flash
  // another place first.
  final zone = ref.watch(deviceTimeZoneProvider);
  if (zone.isLoading && !zone.hasValue) return const AsyncLoading();

  final place = resolvePanchangPlace(
    deviceZone: zone.value,
    profile: ref.watch(birthProfileProvider),
  );
  if (place != null) return AsyncData(place);

  if (live.isLoading) return const AsyncLoading();
  if (live.hasError) return AsyncError(live.error!, live.stackTrace!);
  return const AsyncData(null);
});

/// "Showing timings for {city}…" with a button to try the phone's
/// location again. Shown only when GPS isn't in use.
class PanchangPlaceNote extends ConsumerWidget {
  final PanchangPlace place;

  const PanchangPlaceNote({super.key, required this.place});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden while a lookup runs, so it doesn't flash on first load.
    final locating = ref.watch(currentLocationProvider).isLoading;
    if (!place.isFallback || locating) return const SizedBox.shrink();
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homePanchangFallback(place.location.city ?? ''),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () =>
                ref.read(currentLocationProvider.notifier).refresh(),
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: Text(l10n.homeUseCurrentLocation),
          ),
        ),
      ],
    );
  }
}
