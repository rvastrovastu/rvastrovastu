import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../../your_day/domain/day_strength.dart';
import '../../domain/personal_muhurat.dart';
import '../daily_loop_providers.dart';
import 'loop_card.dart';

/// "Best hours for you today": pick what the time is for, see the best
/// windows left today from your own birth star.
class PersonalMuhuratCard extends ConsumerWidget {
  const PersonalMuhuratCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(personalMuhuratProvider).value;
    if (result == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final purpose = ref.watch(muhuratPurposeProvider);
    final zone = tz.getLocation(result.timezone);

    String time(DateTime utc) => MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(tz.TZDateTime.from(utc, zone)));

    return LoopCard(
      icon: Icons.access_time_filled_rounded,
      title: l10n.muhuratForYouTitle,
      subtitle: l10n.muhuratForYouSubtitle,
      accent: AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in MuhuratPurpose.values)
                ChoiceChip(
                  label: Text(l10n.muhuratPurpose(p.name)),
                  selected: p == purpose,
                  onSelected: (_) =>
                      ref.read(muhuratPurposeProvider.notifier).select(p),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (result.windows.isEmpty)
            Text(
              l10n.muhuratForYouNone,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            for (final (i, w) in result.windows.indexed)
              _WindowRow(
                best: i == 0,
                range: '${time(w.start)} – ${time(w.end)}',
                detail: l10n.muhuratForYouWindow(
                  l10n.choghadiyaName(w.choghadiya.name),
                  l10n.planetName(w.hora),
                  l10n.yourDayTaraName(w.tara.name),
                ),
                weak: w.tara.strength == Strength.bad,
              ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => GoRouter.maybeOf(context)?.push('/muhurat'),
              child: Text(l10n.muhuratPlannerTitle),
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowRow extends StatelessWidget {
  final bool best;
  final String range;
  final String detail;
  final bool weak;

  const _WindowRow({
    required this.best,
    required this.range,
    required this.detail,
    required this.weak,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = best ? AppColors.success : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            best ? Icons.star_rounded : Icons.schedule_rounded,
            size: 18,
            color: color,
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
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: weak ? AppColors.error : AppColors.textSecondary,
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
