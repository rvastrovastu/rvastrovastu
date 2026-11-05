import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_initialization.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  await AppInitialization.initialize();

  runApp(const ProviderScope(child: RvAstroVastuApp()));
}
