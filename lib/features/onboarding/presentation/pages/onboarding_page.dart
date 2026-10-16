import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_initialization.dart';
import '../../../../app/startup_route_resolver.dart';

import '../../../../l10n/app_localizations.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.welcomeTitle,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                l10n.welcomeSubtitle,
                style: Theme.of(context).textTheme.bodyLarge,
              ),

              const SizedBox(height: 40),

              FilledButton(
                onPressed: () => context.go(
                  StartupRouteResolver.routeAfterOnboarding(
                    supabaseConfigured: AppInitialization.supabaseAvailable,
                  ),
                ),
                child: Text(l10n.getStarted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
