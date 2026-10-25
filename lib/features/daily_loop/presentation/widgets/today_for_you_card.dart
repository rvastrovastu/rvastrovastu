import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../../horoscope/presentation/providers/daily_horoscope_provider.dart';
import '../../../your_day/domain/day_strength.dart';
import '../../domain/daily_loop.dart';
import '../daily_loop_providers.dart';

/// "Today for you": the day in five seconds, right under the greeting.
/// Today's one-line reading, the best hour, and where the daily ritual
/// stands (remedy, evening check-in, streak). Hidden without a profile.
class TodayForYouCard extends ConsumerWidget {
  const TodayForYouCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final horoscope = ref.watch(dailyHoroscopeProvider).value;
    if (horoscope == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muhurat = ref.watch(personalMuhuratProvider).value;
    final record = ref.watch(dailyLoopProvider).value;
    final today = ref.watch(loopTodayProvider);
    final remedyDone =
        record?.remedyDays.contains(dayKey(today)) ?? false;
    final checkedIn = record?.checkIns.containsKey(dayKey(today)) ?? false;
    final streak = record == null ? 0 : remedyStreak(record.remedyDays, today);

    final accent = switch (horoscope.verdict) {
      DayVerdict.good => AppColors.success,
      DayVerdict.mixed => AppColors.primary,
      DayVerdict.caution => AppColors.error,
    };

    String? bestHour;
    if (muhurat != null && muhurat.windows.isNotEmpty) {
      final w = muhurat.windows.first;
      final zone = tz.getLocation(muhurat.timezone);
      String time(DateTime utc) => MaterialLocalizations.of(context)
          .formatTimeOfDay(
            TimeOfDay.fromDateTime(tz.TZDateTime.from(utc, zone)),
          );
      bestHour = l10n.reminderMorningBest(
        '${time(w.start)} – ${time(w.end)}',
        l10n.choghadiyaName(w.choghadiya.name),
        l10n.planetName(w.hora),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.18), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                l10n.todayForYouTitle.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.horoscopeHeadline(horoscope.headlineKey),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          if (bestHour != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.access_time_filled_rounded,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    bestHour,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Step(label: l10n.todayRemedyStep, done: remedyDone),
              _Step(label: l10n.todayCheckInStep, done: checkedIn),
              if (streak > 0)
                _Step(
                  label: l10n.dailyRemedyStreak(streak),
                  done: true,
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.accent,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String label;
  final bool done;
  final IconData? icon;
  final Color? color;

  const _Step({
    required this.label,
    required this.done,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? (done ? AppColors.success : AppColors.textMuted);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ??
                (done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded),
            size: 15,
            color: tint,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
