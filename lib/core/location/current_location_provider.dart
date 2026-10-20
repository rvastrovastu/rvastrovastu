import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'current_location.dart';

final currentLocationProvider =
    AsyncNotifierProvider<CurrentLocationNotifier, CurrentLocation?>(
      CurrentLocationNotifier.new,
    );

class CurrentLocationNotifier extends AsyncNotifier<CurrentLocation?> {
  static const _latKey = 'last_location_lat';
  static const _lngKey = 'last_location_lng';
  static const _tzKey = 'last_location_tz';

  @override
  Future<CurrentLocation?> build() async {
    // Show the last place we found straight away, then check quietly
    // whether the phone has moved. GPS can take a while (or never answer
    // on a simulator with no location set), and Today shouldn't wait.
    final cached = await _readCached();
    if (cached != null) {
      Future<void>.microtask(() => _refreshQuietly(cached));
      return cached;
    }
    return _loadCurrentLocation();
  }

  Future<void> _refreshQuietly(CurrentLocation cached) async {
    try {
      final fresh = await _loadCurrentLocation();
      if (fresh != null && !_samePlace(fresh, cached)) {
        state = AsyncData(fresh);
      }
    } catch (_) {
      // Keep showing the saved place.
    }
  }

  /// Within ~1 km and the same time zone: same Panchang.
  static bool _samePlace(CurrentLocation a, CurrentLocation b) =>
      a.timezone == b.timezone &&
      (a.latitude - b.latitude).abs() < 0.01 &&
      (a.longitude - b.longitude).abs() < 0.01;

  Future<CurrentLocation?> _readCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_latKey);
      final lng = prefs.getDouble(_lngKey);
      final tz = prefs.getString(_tzKey);
      if (lat == null || lng == null || tz == null || tz.isEmpty) return null;
      return CurrentLocation(latitude: lat, longitude: lng, timezone: tz);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCached(CurrentLocation location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, location.latitude);
      await prefs.setDouble(_lngKey, location.longitude);
      await prefs.setString(_tzKey, location.timezone);
    } catch (_) {
      // Caching is best-effort.
    }
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

      // Panchang only needs city-level accuracy. Use the last known fix
      // when there is one so Today loads instantly, and never wait more
      // than a few seconds for a new one.
      final position =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
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

      await _saveCached(location);
      return location;
    } catch (error) {
      // Report "no location" rather than an error: a failed provider is
      // retried automatically by Riverpod, which would keep Today loading
      // forever when GPS never answers (e.g. a simulator with no location).
      debugPrint('[LOCATION] UNAVAILABLE: $error');
      return null;
    }
  }
}
