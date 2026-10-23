import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';

/// Two-column grid of the app's tools. Tab destinations (Kundali,
/// Calendar) switch tabs; everything else opens full screen.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final actions = <_Action>[
      _Action(
        Icons.forum_outlined,
        l10n.aiTitle,
        () => context.push('/ask'),
      ),
      _Action(
        Icons.wb_twilight_rounded,
        l10n.rashifalTitle,
        () => context.push('/rashifal'),
      ),
      _Action(
        Icons.shield_moon_outlined,
        l10n.doshaCheckTitle,
        () => context.push('/dosha'),
      ),
      _Action(
        Icons.favorite_outline,
        l10n.compatTitle,
        () => context.push('/compatibility'),
      ),
      _Action(
        Icons.calendar_month,
        l10n.muhuratPlannerTitle,
        () => context.push('/muhurat'),
      ),
      _Action(
        Icons.celebration_outlined,
        l10n.festivalCalendarTitle,
        () => context.go('/festivals'),
      ),
      _Action(
        Icons.auto_awesome,
        l10n.homeMyKundali,
        () => context.go('/kundali'),
      ),
      _Action(
        Icons.person_outline,
        l10n.homeBirthProfile,
        () => context.push('/saved-profiles'),
      ),
      _Action(
        Icons.diamond_outlined,
        l10n.remediesTitle,
        () => context.push('/remedies'),
      ),
      _Action(
        Icons.pin_outlined,
        l10n.numerologyTitle,
        () => context.push('/numerology'),
      ),
      _Action(
        Icons.child_care_rounded,
        l10n.babyNamesTitle,
        () => context.push('/baby-names'),
      ),
      _Action(
        Icons.explore,
        l10n.vastuCompassTitle,
        () => context.go('/vastu/compass'),
      ),
      _Action(
        Icons.notifications_active_outlined,
        l10n.remindersTitle,
        () => context.push('/reminders'),
      ),
      _Action(
        Icons.workspace_premium_rounded,
        l10n.premiumTitle,
        () => context.push('/premium'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final width = (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in actions)
              SizedBox(width: width, child: _ActionTile(action: action)),
          ],
        );
      },
    );
  }
}

class _Action {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _Action(this.icon, this.title, this.onTap);
}

class _ActionTile extends StatelessWidget {
  final _Action action;

  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.outline, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surfaceLight, AppColors.surface],
          ),
        ),
        child: InkWell(
          onTap: action.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      action.icon,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    action.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
