import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/astrology_provider.dart';
import 'kundali_page.dart';

class KundaliLoaderPage extends ConsumerWidget {
  const KundaliLoaderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kundali = ref.watch(kundaliProvider);

    return kundali.when(
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Calculating your Kundali...'),
            ],
          ),
        ),
      ),

      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Kundali')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Unable to calculate Kundali',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(kundaliProvider);
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),

      data: (data) {
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Kundali')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline, size: 56),
                    const SizedBox(height: 20),
                    const Text(
                      'Birth Profile Required',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Create your birth profile before viewing your Kundali.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        context.go('/birth-profile');
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Create Birth Profile'),
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
