import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';

class DashboardLoading extends StatelessWidget {
  const DashboardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class DashboardError extends StatelessWidget {
  final VoidCallback onRetry;

  const DashboardError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42),
          SizedBox(height: 12),
          Text(
            context.l10n.homeUnableToCalculateKundali,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(context.l10n.homePleaseTryAgain, textAlign: TextAlign.center),
          SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(context.l10n.homeRetry)),
        ],
      ),
    );
  }
}

class NoProfileCard extends StatelessWidget {
  final VoidCallback onTap;

  const NoProfileCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.person_add_alt_1_rounded, size: 42),
          SizedBox(height: 12),
          Text(
            context.l10n.homeCompleteBirthProfile,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            context.l10n.homeBirthProfileDescription,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 18),
          FilledButton(
            onPressed: onTap,
            child: Text(context.l10n.homeSetUpProfile),
          ),
        ],
      ),
    );
  }
}
