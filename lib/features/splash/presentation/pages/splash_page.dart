import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/config/app_initialization.dart';
import '../../../auth/data/auth_service.dart';
import '../../../../app/startup_route_resolver.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  Timer? _navigationTimer;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();

    _navigationTimer = Timer(const Duration(seconds: 2), _navigateNext);
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;

    final hasLanguage = await ref
        .read(languageProvider.notifier)
        .hasSavedLanguage();

    if (!mounted) return;

    if (!hasLanguage) {
      context.go('/language');
      return;
    }

    await ref.read(birthProfileProvider.notifier).loadProfile();

    if (!mounted) return;

    final profile = ref.read(birthProfileProvider);

    final route = StartupRouteResolver.routeAfterSplash(
      hasSavedLanguage: true,
      hasProfile: profile != null,
      supabaseConfigured: AppInitialization.supabaseAvailable,
      authenticated: AuthService().isAuthenticated,
    );

    if (!mounted) return;
    context.go(route);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _navigationTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 54,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.appName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.welcomeSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 36),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
