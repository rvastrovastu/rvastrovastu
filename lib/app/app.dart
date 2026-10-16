import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_language.dart';
import '../core/localization/language_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/time/app_clock_provider.dart';
import '../features/reminders/presentation/providers/reminder_providers.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';

class RvAstroVastuApp extends ConsumerStatefulWidget {
  const RvAstroVastuApp({super.key});

  @override
  ConsumerState<RvAstroVastuApp> createState() => _RvAstroVastuAppState();
}

class _RvAstroVastuAppState extends ConsumerState<RvAstroVastuApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh the rolling window of reminders once the app is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reminderSchedulerProvider).sync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appClockProvider.notifier).refresh();
      ref.read(reminderSchedulerProvider).sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);

    return MaterialApp.router(
      title: 'RV Astro Vastu',
      debugShowCheckedModeBanner: false,

      locale: Locale(language.code),

      supportedLocales: AppLanguage.values
          .map((language) => Locale(language.code))
          .toList(),

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: AppTheme.dark(),

      routerConfig: AppRouter.router,
    );
  }
}
