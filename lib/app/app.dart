import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class RvAstroVastuApp extends StatelessWidget {
  const RvAstroVastuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RV Astro Vastu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: AppRouter.router,
    );
  }
}
