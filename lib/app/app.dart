import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/localization/app_language.dart';
import '../core/localization/language_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/layout/app_frame.dart';
import '../core/time/app_clock_provider.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/reminders/presentation/providers/reminder_providers.dart';
import '../features/today_widget/today_widget_sync.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';

class RvAstroVastuApp extends ConsumerStatefulWidget {
  const RvAstroVastuApp({super.key});

  @override
  ConsumerState<RvAstroVastuApp> createState() => _RvAstroVastuAppState();
}

class _RvAstroVastuAppState extends ConsumerState<RvAstroVastuApp>
    with WidgetsBindingObserver {
  Timer? _reminderSyncTimer;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = ref.read(authServiceProvider).authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        AppRouter.router.go('/account/new-password');
      }
    });
    // Refresh the rolling window of reminders once the first screens have
    // loaded, so it never competes with today's Panchang.
    _reminderSyncTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      ref.read(reminderSchedulerProvider).sync();
      ref.read(todayWidgetSyncProvider).sync();
    });
  }

  @override
  void dispose() {
    _reminderSyncTimer?.cancel();
    _authSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appClockProvider.notifier).refresh();
      ref.read(reminderSchedulerProvider).sync();
      ref.read(todayWidgetSyncProvider).sync();
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

      theme: AppTheme.dark(language.code),

      routerConfig: AppRouter.router,
      builder: (context, child) => AppFrame(child: child ?? const SizedBox.shrink()),
    );
  }
}
