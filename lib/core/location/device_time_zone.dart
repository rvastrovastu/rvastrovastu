import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

import 'current_location.dart';
import 'time_zone_coordinates.dart';

/// The phone's time zone setting (an IANA id such as 'America/Chicago'),
/// or null when it can't be read.
final deviceTimeZoneProvider = FutureProvider<String?>((ref) async {
  try {
    final id = (await FlutterTimezone.getLocalTimezone()).identifier;
    return id.trim().isEmpty ? null : id;
  } catch (_) {
    return null;
  }
});

/// [zone] under its current name ('Asia/Calcutta' → 'Asia/Kolkata').
String canonicalZone(String zone) => zoneAliases[zone] ?? zone;

bool sameZone(String a, String b) => canonicalZone(a) == canonicalZone(b);

/// The principal city of time zone [zone], e.g. Chicago for
/// 'America/Chicago'. Null for zones with no city (UTC, Etc/GMT+5).
CurrentLocation? timeZonePlace(String zone) {
  final canonical = canonicalZone(zone);
  final coordinates = zoneCoordinates[canonical];
  if (coordinates == null) return null;
  final (latitude, longitude) = coordinates;
  return CurrentLocation(
    latitude: latitude,
    longitude: longitude,
    timezone: _knownZone(zone, canonical),
    city: canonical.split('/').last.replaceAll('_', ' '),
  );
}

/// Whichever of the two names the time zone database knows.
String _knownZone(String zone, String canonical) {
  try {
    tz.getLocation(zone);
    return zone;
  } catch (_) {
    return canonical;
  }
}
