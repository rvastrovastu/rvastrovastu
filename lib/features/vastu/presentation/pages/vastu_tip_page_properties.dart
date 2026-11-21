// The Vastu tab's saved properties: list, property cards and the add card.
part of 'vastu_tip_page.dart';

// ---------------------------------------------------------------------------
// Properties

class _PropertiesSection extends ConsumerWidget {
  const _PropertiesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final layouts = ref.watch(vastuLayoutsProvider).value ?? const [];

    if (layouts.isEmpty) {
      return Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3A2F5E), AppColors.surface],
            ),
          ),
          child: InkWell(
            onTap: () => context.push('/vastu/plans'),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.16),
                    ),
                    child: const Icon(
                      Icons.architecture_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.vastuPlansCta,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.vastuPlansSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: l10n.vastuHubPropertiesTitle,
          action: TextButton(
            onPressed: () => context.push('/vastu/plans'),
            child: Text(l10n.vastuAllProperties),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final layout in layouts) ...[
                _PropertyCard(layout: layout),
                const SizedBox(width: 12),
              ],
              _AddPropertyCard(label: l10n.vastuPlansAdd),
            ],
          ),
        ),
      ],
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final VastuLayout layout;

  const _PropertyCard({required this.layout});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    VastuAnalysis? analysis;
    try {
      analysis = VastuAnalysis.of(layout);
    } catch (error, stack) {
      Telemetry.recordError(error, stack, reason: 'vastu_analysis');
      analysis = null;
    }
    final score = analysis?.score;
    final color = switch (analysis?.band) {
      VastuScoreBand.excellent => AppColors.success,
      VastuScoreBand.good => AppColors.primary,
      VastuScoreBand.average => AppColors.accent,
      VastuScoreBand.attention => AppColors.error,
      null => AppColors.textMuted,
    };

    return SizedBox(
      width: 150,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/vastu/plans/${layout.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 58,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: (score ?? 0) / 100,
                          strokeWidth: 5,
                          backgroundColor: AppColors.outline,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                      Text(
                        score?.toString() ?? '–',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  layout.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  l10n.vastuScoreTitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
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

class _AddPropertyCard extends StatelessWidget {
  final String label;

  const _AddPropertyCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/vastu/plans/new'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_home_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
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
