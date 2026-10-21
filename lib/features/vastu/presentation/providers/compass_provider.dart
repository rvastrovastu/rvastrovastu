import 'dart:async';

import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long to wait for a first reading before treating the device as
/// having no compass. The iOS simulator and some Android phones expose
/// the sensor stream but never send anything on it.
const compassFirstReadingTimeout = Duration(seconds: 2);

/// Live magnetic heading in degrees (0 = North), or `null` when the device
/// has no working compass sensor.
final compassHeadingProvider = StreamProvider.autoDispose<double?>((ref) {
  final events = FlutterCompass.events;
  if (events == null) return Stream<double?>.value(null);
  return headingsWithTimeout(
    events.map((event) => event.heading),
    compassFirstReadingTimeout,
  );
});

/// Passes [readings] through, but emits `null` if the first one doesn't
/// arrive within [timeout], and turns errors into `null`. Later readings
/// still come through, so a slow sensor recovers.
Stream<double?> headingsWithTimeout(
  Stream<double?> readings,
  Duration timeout,
) {
  late final StreamController<double?> controller;
  StreamSubscription<double?>? subscription;
  Timer? timer;
  var received = false;

  controller = StreamController<double?>(
    onListen: () {
      timer = Timer(timeout, () {
        if (!received) controller.add(null);
      });
      subscription = readings.listen(
        (heading) {
          received = true;
          timer?.cancel();
          controller.add(heading);
        },
        onError: (Object _) => controller.add(null),
        onDone: controller.close,
      );
    },
    onCancel: () async {
      timer?.cancel();
      await subscription?.cancel();
    },
  );
  return controller.stream;
}
