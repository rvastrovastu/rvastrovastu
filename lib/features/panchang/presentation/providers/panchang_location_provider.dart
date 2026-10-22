import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/location/current_location.dart';
import '../../../../core/location/current_location_provider.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';

/// Where Panchang timings are calculated for.
class PanchangPlace {
  final CurrentLocation location;

  /// True when the phone's location isn't available and the active birth
  /// profile's city is used instead.
  final bool fromProfile;

  const PanchangPlace(this.location, {this.fromProfile = false});
}

/// The phone's location, or the active birth profile's city when GPS is
/// off, denied or doesn't answer. Shared by Today, Daily Timing and the
/// Muhurat planner so they always agree.
final panchangPlaceProvider = Provider<AsyncValue<PanchangPlace?>>((ref) {
  final live = ref.watch(currentLocationProvider);
  if (live.value case final location?) return AsyncData(PanchangPlace(location));

  final profile = ref.watch(birthProfileProvider);
  final hasProfilePlace =
      profile != null && profile.location.timezone.trim().isNotEmpty;
  if (hasProfilePlace) {
    // Also used while the first lookup runs, so nothing waits on GPS.
    return AsyncData(
      PanchangPlace(
        CurrentLocation(
          latitude: profile.location.latitude,
          longitude: profile.location.longitude,
          timezone: profile.location.timezone,
          city: profile.location.city,
        ),
        fromProfile: true,
      ),
    );
  }

  if (live.isLoading) return const AsyncLoading();
  if (live.hasError) return AsyncError(live.error!, live.stackTrace!);
  return const AsyncData(null);
});

/// "Showing timings for {city}…" with a button to try the phone's
/// location again. Shown only when the profile city is in use.
class PanchangPlaceNote extends ConsumerWidget {
  final PanchangPlace place;

  const PanchangPlaceNote({super.key, required this.place});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden while a lookup runs, so it doesn't flash on first load.
    final locating = ref.watch(currentLocationProvider).isLoading;
    if (!place.fromProfile || locating) return const SizedBox.shrink();
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
