import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/astrology_provider.dart';
import 'kundali_page.dart';

class KundaliLoaderPage extends ConsumerWidget {
  const KundaliLoaderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final kundali = ref.watch(kundaliProvider);

    return kundali.when(
      loading: () => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(l10n.calculatingYourKundali),
            ],
          ),
        ),
      ),

      error: (error, stack) => Scaffold(
        appBar: AppBar(
          title: Text(l10n.kundali),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.unableToCalculateKundali,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(kundaliProvider);
                  },
                  child: Text(l10n.tryAgain),
                ),
              ],
            ),
          ),
        ),
      ),

      data: (data) {
        if (data == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.kundali),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 56,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.birthProfileRequired,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.createBirthProfileBeforeViewingKundali,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        context.go('/birth-profile');
                      },
                      icon: const Icon(
                        Icons.person_add_alt_1,
                      ),
                      label: Text(
                        l10n.createBirthProfile,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return KundaliPage(kundali: data);
      },
    );
  }
}
