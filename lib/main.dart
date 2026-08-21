import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_initialization.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppInitialization.initialize();

  runApp(const ProviderScope(child: RvAstroVastuApp()));
}
