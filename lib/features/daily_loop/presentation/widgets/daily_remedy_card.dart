import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../domain/daily_loop.dart';
import '../daily_loop_providers.dart';
import 'loop_card.dart';

/// "Today's small remedy": one free practice for the running dasha, a
/// button to mark it done, and the streak.
class DailyRemedyCard extends ConsumerWidget {
  const DailyRemedyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remedy = ref.watch(dailyRemedyProvider);
    final record = ref.watch(dailyLoopProvider).value;
    if (remedy == null || record == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final today = ref.watch(loopTodayProvider);
    final done = record.remedyDays.contains(dayKey(today));
    final streak = remedyStreak(record.remedyDays, today);
    final planet = l10n.planetName(capitalisedPlanet(remedy.planet));

    final practice = switch (remedy.kind) {
      RemedyKind.mantra => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.remediesMantra(remedy.planet),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.remediesMantraLatin(remedy.planet),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Text(l10n.dailyRemedyMantraHow),
        ],
      ),
      RemedyKind.charity => Text(
        l10n.dailyRemedyCharity(l10n.remediesCharityItems(remedy.planet)),
        style: theme.textTheme.bodyLarge,
      ),
      RemedyKind.worship => Text(
        l10n.dailyRemedyWorship(l10n.remediesDeityName(remedy.planet)),
        style: theme.textTheme.bodyLarge,
      ),
    };

    return LoopCard(
      icon: Icons.spa_rounded,
      title: l10n.dailyRemedyTitle,
      subtitle: remedy.forDasha
          ? l10n.dailyRemedyForDasha(planet)
          : l10n.dailyRemedyForWeekday(planet),
      accent: AppColors.accent,
      trailing: _StreakBadge(streak: streak),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          practice,
          const SizedBox(height: 8),
          Text(
            l10n.dailyRemedyFree,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          done
              ? Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.dailyRemedyDoneToday,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              : FilledButton.tonal(
                  onPressed: () =>
                      ref.read(dailyLoopProvider.notifier).markRemedyDone(),
                  child: Text(l10n.dailyRemedyMarkDone),
                ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;

  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    final active = streak > 0;
    final color = active ? AppColors.accent : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            context.l10n.dailyRemedyStreak(streak),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
