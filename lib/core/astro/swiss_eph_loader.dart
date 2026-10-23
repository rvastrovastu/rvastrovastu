import 'dart:io';

import 'package:swisseph/swisseph.dart';

/// Opens the bundled Swiss Ephemeris library for this platform. Callers
/// close it when done.
Future<SwissEph> loadSwissEph() async {
  if (Platform.isIOS) {
    final appDirectory = File(Platform.resolvedExecutable).parent;
    final framework =
        '${appDirectory.path}/Frameworks/swisseph.framework/swisseph';
    if (File(framework).existsSync()) return SwissEph(framework);
    throw StateError('Swiss Ephemeris framework not found at: $framework');
  }
  if (Platform.isMacOS) {
    final contents = File(Platform.resolvedExecutable).parent.parent;
    final framework = '${contents.path}/Frameworks/swisseph.framework/swisseph';
    if (File(framework).existsSync()) return SwissEph(framework);
  }
  return SwissEph.load();
}
