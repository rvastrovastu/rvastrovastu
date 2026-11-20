import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../../panchang/presentation/widgets/plan_week_links.dart';
import '../../../panchang/presentation/widgets/plan_your_day_strip.dart';
import '../../../your_day/domain/day_strength.dart';
import '../../domain/personal_muhurat.dart';
import '../daily_loop_providers.dart';

/// "Best times for you": the user picks what the time is for (start
/// something, money and buying, travel, meeting people), each shown with
/// everyday examples, and sees the best windows left today, checked
/// against their own birth star, each with why in plain words.
class ForYouTimingsCard extends StatelessWidget {
  const ForYouTimingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TimingsCard(
      icon: Icons.stars_rounded,
      title: l10n.forYouTimingsTitle,
      subtitle: l10n.muhuratForYouSubtitle,
      footer: const PlanWeekLinks(forYou: true),
      child: const PersonalMuhuratBody(),
    );
  }
}

/// The inside of [ForYouTimingsCard]: purpose picker and today's windows.
class PersonalMuhuratBody extends ConsumerWidget {
  const PersonalMuhuratBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final purpose = ref.watch(muhuratPurposeProvider);
    final async = ref.watch(personalMuhuratProvider);
    final result = async.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.forYouAskPurpose,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            final width = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final p in MuhuratPurpose.values)
                  SizedBox(
                    width: width,
                    child: _PurposeTile(
                      purpose: p,
                      selected: p == purpose,
                      onTap: () =>
                          ref.read(muhuratPurposeProvider.notifier).select(p),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          l10n.forYouBestTimesFor(l10n.muhuratPurpose(purpose.name)),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        if (result == null)
          async.isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                )
              : const SizedBox.shrink()
        else if (result.windows.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bedtime_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.muhuratForYouNone,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ..._windows(context, result),
      ],
    );
  }

  List<Widget> _windows(
    BuildContext context,
    ({List<MuhuratWindow> windows, String timezone}) result,
  ) {
    final l10n = context.l10n;
    final zone = tz.getLocation(result.timezone);
    String time(DateTime utc) => MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(tz.TZDateTime.from(utc, zone)));

    return [
      for (final (i, w) in result.windows.indexed)
        _WindowRow(
          best: i == 0,
          range: '${time(w.start)} – ${time(w.end)}',
          reason: l10n.muhuratForYouReason(
            l10n.choghadiyaName(w.choghadiya.name),
            l10n.planetName(w.hora),
          ),
          star: l10n.muhuratForYouStar(w.tara.strength.name),
          strength: w.tara.strength,
        ),
    ];
  }
}

class _PurposeTile extends StatelessWidget {
  final MuhuratPurpose purpose;
  final bool selected;
  final VoidCallback onTap;

  const _PurposeTile({
    required this.purpose,
    required this.selected,
    required this.onTap,
  });

  static IconData _icon(MuhuratPurpose p) => switch (p) {
    MuhuratPurpose.start => Icons.rocket_launch_rounded,
    MuhuratPurpose.money => Icons.shopping_bag_rounded,
    MuhuratPurpose.travel => Icons.flight_takeoff_rounded,
    MuhuratPurpose.people => Icons.groups_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.14)
            : AppColors.surface.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('purpose_${purpose.name}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_icon(purpose), size: 18, color: color),
                    const Spacer(),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.muhuratPurpose(purpose.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? AppColors.primary : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.muhuratPurposeHint(purpose.name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowRow extends StatelessWidget {
  final bool best;
  final String range;
  final String reason;
  final String star;
  final Strength strength;

  const _WindowRow({
    required this.best,
    required this.range,
    required this.reason,
    required this.star,
    required this.strength,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final starColor = switch (strength) {
      Strength.good => AppColors.success,
      Strength.weak => AppColors.warning,
      Strength.bad => AppColors.error,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: best
            ? AppColors.success.withValues(alpha: 0.10)
            : AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: best
              ? AppColors.success.withValues(alpha: 0.6)
              : AppColors.outline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            best ? Icons.star_rounded : Icons.schedule_rounded,
            size: 20,
            color: best ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        range,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (best) ...[
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.muhuratForYouBest,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  star,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: starColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
