import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../l10n/app_localizations.dart';

class LanguagePreferencePage extends ConsumerWidget {
  const LanguagePreferencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final l10n = AppLocalizations.of(context);

    final isEditing =
        GoRouterState.of(context).uri.queryParameters['edit'] == 'true';

    return Scaffold(
      appBar: isEditing
          ? AppBar(
              title: Text(l10n.languagePreference),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isEditing) const Spacer(),

              if (isEditing)
                const Icon(Icons.language_rounded, size: 64)
              else
                const Center(child: AppLogo(size: 104, glow: true)),

              const SizedBox(height: 24),

              Text(
                l10n.languagePreference,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                l10n.selectLanguage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),

              const SizedBox(height: 28),

              Expanded(
                child: RadioGroup<AppLanguage>(
                  groupValue: language,
                  onChanged: (value) async {
                    if (value == null) return;

                    await ref
                        .read(languageProvider.notifier)
                        .setLanguage(value);
                  },
                  child: ListView.separated(
                    itemCount: AppLanguage.values.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = AppLanguage.values[index];

                      return Card(
                        child: RadioListTile<AppLanguage>(
                          value: item,
                          title: Text(item.nativeName),
                          subtitle: Text(item.name),
                          secondary: Text(
                            item.code.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              FilledButton(
                onPressed: () {
                  if (isEditing) {
                    context.pop();
                  } else {
                    context.go('/onboarding');
                  }
                },
                child: Text(l10n.continueButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
