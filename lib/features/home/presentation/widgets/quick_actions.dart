import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';

/// A short, scrollable row of the most-used tools. Everything else lives
/// in the menu, which the last tile opens.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final actions = <_Action>[
      _Action(Icons.forum_outlined, l10n.aiTitle, () => context.push('/ask')),
      _Action(
        Icons.support_agent_rounded,
        l10n.consultShort,
        () => context.go('/consult'),
      ),
      _Action(
        Icons.wb_sunny_outlined,
        l10n.rashifalTitle,
        () => context.push('/rashifal'),
      ),
      _Action(
        Icons.calendar_month,
        l10n.muhuratPlannerTitle,
        () => context.push('/muhurat'),
      ),
      _Action(
        Icons.favorite_outline,
        l10n.compatTitle,
        () => context.push('/compatibility'),
      ),
      _Action(
        Icons.shield_moon_outlined,
        l10n.doshaCheckTitle,
        () => context.push('/dosha'),
      ),
      _Action(
        Icons.diamond_outlined,
        l10n.remediesTitle,
        () => context.push('/remedies'),
      ),
      _Action(
        Icons.apps_rounded,
        l10n.homeAllFeatures,
        () => Scaffold.maybeOf(context)?.openDrawer(),
        highlight: true,
      ),
    ];

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: actions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) => _ActionTile(action: actions[index]),
      ),
    );
  }
}

class _Action {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool highlight;

  const _Action(this.icon, this.title, this.onTap, {this.highlight = false});
}

class _ActionTile extends StatelessWidget {
  final _Action action;

  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 80,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: action.highlight
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primaryLight, AppColors.primary],
                        )
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.surfaceLight, AppColors.surface],
                        ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  action.icon,
                  size: 24,
                  color: action.highlight
                      ? AppColors.onPrimary
                      : AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                action.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
