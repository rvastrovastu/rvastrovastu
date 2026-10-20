import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live magnetic heading in degrees (0 = North), or `null` when the device
/// has no compass sensor (e.g. the iOS simulator or some Android phones).
final compassHeadingProvider = StreamProvider.autoDispose<double?>((ref) {
  final events = FlutterCompass.events;
  if (events == null) return Stream<double?>.value(null);
  return events.map((event) => event.heading);
});
