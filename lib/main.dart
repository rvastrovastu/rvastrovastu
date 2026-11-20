import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_initialization.dart';
import 'core/telemetry/telemetry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Release builds: many logs print birth details, places and names. Keep
  // only the store and payment diagnostics, which hold no personal data.
  if (kReleaseMode) {
    final printToConsole = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && _releaseLogTags.any(message.startsWith)) {
        printToConsole(message, wrapWidth: wrapWidth);
      }
    };
  }

  // Place-of-birth search uses GeoNames data (CC BY 4.0).
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(
        ['GeoNames'],
        'City and region names and coordinates from GeoNames '
        '(https://www.geonames.org), licensed under Creative Commons '
        'Attribution 4.0 (https://creativecommons.org/licenses/by/4.0/).',
      ),
    ),
  );

  // Crash reports and product events (does nothing until Firebase is set up).
  await Telemetry.init();
  Telemetry.captureUncaughtErrors();

  await AppInitialization.initialize();

  runApp(const ProviderScope(child: RvAstroVastuApp()));
}

/// Log prefixes still printed in release builds (see main).
const _releaseLogTags = ['[PURCHASE]', '[STORE]', '[PAYWALL]', '[MEMBERSHIP]'];
