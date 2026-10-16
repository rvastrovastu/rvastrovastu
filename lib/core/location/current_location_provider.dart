import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart';
import 'package:geolocator/geolocator.dart';

import 'current_location.dart';

final currentLocationProvider =
    AsyncNotifierProvider<CurrentLocationNotifier, CurrentLocation?>(
      CurrentLocationNotifier.new,
    );

class CurrentLocationNotifier extends AsyncNotifier<CurrentLocation?> {
  @override
  Future<CurrentLocation?> build() async {
    return _loadCurrentLocation();
  }

  Future<CurrentLocation?> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(_loadCurrentLocation);

    return state.when(
      data: (location) => location,
      loading: () => null,
      error: (_, _) => null,
    );
  }

  Future<CurrentLocation?> _loadCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint('[LOCATION] Location services are disabled.');
        return null;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        debugPrint('[LOCATION] Location permission denied.');
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LOCATION] Location permission permanently denied.');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final timezone = latLngToTimezoneString(
        position.latitude,
        position.longitude,
      );

      final location = CurrentLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        timezone: timezone,
      );

      debugPrint(
        '[LOCATION] SUCCESS '
        'lat=${location.latitude} '
        'lng=${location.longitude} '
        'tz=${location.timezone}',
      );

      return location;
    } catch (error, stack) {
      debugPrint('[LOCATION] ERROR: $error');
      debugPrint('[LOCATION] STACK: $stack');
      rethrow;
    }
  }
}
