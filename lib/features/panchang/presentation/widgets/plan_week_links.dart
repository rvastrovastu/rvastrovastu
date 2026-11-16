import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../membership/domain/membership.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../membership/presentation/widgets/premium_gate.dart';

/// "Plan ahead" footer inside the Panchang card: one premium button that
/// opens the next seven days in the view the card is showing.
class PlanWeekLinks extends ConsumerWidget {
  const PlanWeekLinks({super.key, required this.forYou});

  /// True when the "For you" tab is showing, false for "Today".
  final bool forYou;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(canUseProvider(PremiumFeature.dayPlanner));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.event_note_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              l10n.planAheadTitle,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (!premium) const _PremiumBadge(),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          forYou ? l10n.planAheadForYou : l10n.planAheadToday,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => premium
                ? context.push('/plan-days?view=${forYou ? 'you' : 'today'}')
                : openPaywall(context, PremiumFeature.dayPlanner),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_view_week_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.planNext7Days,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    premium ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        l10n.premiumBadge,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
