import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/app_clock_provider.dart';
import '../../../horoscope/presentation/providers/daily_horoscope_provider.dart';
import '../../domain/daily_loop.dart';
import '../daily_loop_providers.dart';
import 'loop_card.dart';

/// "Did today match your reading?": one tap in the evening, and over time
/// the share of days the readings matched.
class NightCheckInCard extends ConsumerWidget {
  /// The card appears from this hour (local time).
  static const fromHour = 17;

  const NightCheckInCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(dailyLoopProvider).value;
    final horoscope = ref.watch(dailyHoroscopeProvider).value;
    if (record == null || horoscope == null) return const SizedBox.shrink();

    final now = ref.watch(appClockProvider);
    final today = ref.watch(loopTodayProvider);
    final answer = record.checkIns[dayKey(today)];
    if (answer == null && now.hour < fromHour) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rate = matchRate(record.checkIns, today);

    return LoopCard(
      icon: Icons.nightlight_round,
      title: l10n.checkInTitle,
      subtitle: l10n.horoscopeHeadline(horoscope.headlineKey),
      accent: AppColors.primaryLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final option in CheckIn.values) ...[
                if (option != CheckIn.yes) const SizedBox(width: 8),
                Expanded(
                  child: option == answer
                      ? FilledButton(
                          onPressed: () => ref
                              .read(dailyLoopProvider.notifier)
                              .checkIn(option),
                          child: Text(l10n.checkInAnswer(option.name)),
                        )
                      : OutlinedButton(
                          onPressed: () => ref
                              .read(dailyLoopProvider.notifier)
                              .checkIn(option),
                          child: Text(l10n.checkInAnswer(option.name)),
                        ),
                ),
              ],
            ],
          ),
          if (answer != null) ...[
            const SizedBox(height: 10),
            Text(
              l10n.checkInThanks,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            rate == null
                ? l10n.checkInWhy
                : l10n.checkInRate(rate.percent, rate.days),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
