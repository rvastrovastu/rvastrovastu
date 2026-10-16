import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extension.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.greeting,
    required this.profileGreeting,
    required this.dateText,
  });

  final String greeting;
  final String profileGreeting;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'RV ASTRO VASTU',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.auto_awesome, size: 15, color: colors.primary),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  '$greeting,',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profileGreeting,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  dateText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton.filledTonal(
                tooltip: context.l10n.homeLanguage,
                onPressed: () {
                  context.push('/language?edit=true');
                },
                icon: const Icon(Icons.language),
              ),
              const SizedBox(height: 4),
              IconButton(
                tooltip: context.l10n.homeEditBirthProfile,
                onPressed: () {
                  context.push('/birth-profile?edit=true');
                },
                icon: const Icon(Icons.person_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
