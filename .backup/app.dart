import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/language_provider.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';

class RvAstroVastuApp extends ConsumerWidget {
  const RvAstroVastuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);

    return MaterialApp.router(
      title: 'RV Astro Vastu',
      debugShowCheckedModeBanner: false,

      locale: language.locale,

      localizationsDelegates: AppLocalizations.localizationsDelegates,

      supportedLocales: AppLocalizations.supportedLocales,

      theme: AppTheme.dark(),

      routerConfig: AppRouter.router,
    );
  }
}
