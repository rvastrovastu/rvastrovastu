import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/celestial_background.dart';
import '../providers/auth_provider.dart';

/// Welcome screen after onboarding: create an account or sign in (both
/// by emailed code), or continue as a guest and sign in later.
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  bool _loading = false;

  Future<void> _continueAsGuest() async {
    setState(() => _loading = true);

    try {
      await ref.read(authServiceProvider).signInAnonymously();
      if (!mounted) return;
      context.go('/home');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.unableToContinue('$error'))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return Scaffold(
      body: CelestialBackground(
        starCoverage: 0.9,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 150, glow: true)),
                    const SizedBox(height: 32),
                    Text(
                      l10n.welcomeTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.authTagline,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _loading
                            ? null
                            : () => context.push(
                                '/account?next=/home&mode=create',
                              ),
                        style: FilledButton.styleFrom(shape: buttonShape),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(
                          l10n.authCreateAccount,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => context.push('/account?next=/home'),
                        style: OutlinedButton.styleFrom(
                          shape: buttonShape,
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        icon: const Icon(Icons.login_rounded),
                        label: Text(
                          l10n.authSignIn,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: _loading ? null : _continueAsGuest,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.authContinueGuest),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.authGuestNote,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
