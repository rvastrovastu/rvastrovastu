import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/app_clock_provider.dart';
import '../../domain/entities/vastu_zone.dart';
import '../../layout/domain/vastu_analysis.dart';
import '../../layout/domain/vastu_layout.dart';
import '../../layout/presentation/vastu_layout_providers.dart';
import '../../layout/presentation/vastu_layout_text.dart';
import '../providers/vastu_tip_provider.dart';
import '../widgets/vastu_chakra.dart';

/// The Vastu hub: an interactive 16-zone chakra, the tools, your saved
/// properties with their scores, a room-by-room placement guide and the
/// tip of the day.
class VastuTipPage extends ConsumerStatefulWidget {
  const VastuTipPage({super.key});

  @override
  ConsumerState<VastuTipPage> createState() => _VastuTipPageState();
}

class _VastuTipPageState extends ConsumerState<VastuTipPage> {
  VastuZone _zone = VastuZone.ne;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vastu)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChakraHero(
                zone: _zone,
                onSelect: (zone) => setState(() => _zone = zone),
              ),
              const SizedBox(height: 16),
              const _ToolsRow(),
              const SizedBox(height: 12),
              const _ExpertCta(),
              const SizedBox(height: 24),
              const _PropertiesSection(),
              const SizedBox(height: 24),
              const _RoomGuide(),
              const SizedBox(height: 24),
              const _TipCard(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chakra

class _ChakraHero extends StatelessWidget {
  final VastuZone zone;
  final ValueChanged<VastuZone> onSelect;

  const _ChakraHero({required this.zone, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final element = elementOfZone(zone);

    return _Panel(
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.vastuHubChakraTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.vastuHubChakraHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          VastuChakra(selected: zone, onSelect: onSelect),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final e in VastuElement.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: e.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      l10n.vastuElement(e.name),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Container(
              key: ValueKey(zone),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (element?.color ?? AppColors.primary).withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.vastuZoneName(zone.name),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                      if (element != null)
                        _Pill(
                          text: l10n.vastuElement(element.name),
                          color: element.color,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.vastuZoneTheme(zone.name),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _LabelledLine(
                    icon: Icons.check_circle_rounded,
                    color: AppColors.success,
                    label: l10n.vastuBestFor,
                    value: l10n.vastuZoneBest(zone.name),
                  ),
                  const SizedBox(height: 6),
                  _LabelledLine(
                    icon: Icons.do_not_disturb_on_rounded,
                    color: AppColors.error,
                    label: l10n.vastuAvoid,
                    value: l10n.vastuZoneAvoid(zone.name),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tools

class _ToolsRow extends StatelessWidget {
  const _ToolsRow();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ToolTile(
              icon: Icons.explore_rounded,
              colors: const [Color(0xFF6FC79A), Color(0xFF2E8A6B)],
              title: l10n.vastuCompassTitle,
              subtitle: l10n.vastuCompassSubtitle,
              onTap: () => context.push('/vastu/compass'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ToolTile(
              icon: Icons.door_front_door_rounded,
              colors: const [Color(0xFFF7CF78), Color(0xFFB8741A)],
              title: l10n.vastuEntranceAnalysis,
              subtitle: l10n.vastuHubEntranceSubtitle,
              onTap: () => context.push('/vastu/entrance'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpertCta extends StatelessWidget {
  const _ExpertCta();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/consult?topic=vastu'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(
                Icons.support_agent_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.consultVastuCta,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.consultVastuCtaBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    } catch (_) {
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

// ---------------------------------------------------------------------------
// Room guide

class _RoomGuide extends StatefulWidget {
  const _RoomGuide();

  @override
  State<_RoomGuide> createState() => _RoomGuideState();
}

class _RoomGuideState extends State<_RoomGuide> {
  static const _rooms = [
    VastuRoom.kitchen,
    VastuRoom.masterBedroom,
    VastuRoom.pooja,
    VastuRoom.living,
    VastuRoom.study,
    VastuRoom.childrenRoom,
    VastuRoom.toilet,
    VastuRoom.cashLocker,
    VastuRoom.staircase,
    VastuRoom.undergroundWater,
  ];

  VastuRoom _room = VastuRoom.kitchen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rule = vastuRules[_room]!;
    final ideal = idealZonesFor(_room);
    final avoid = [
      for (final z in VastuZone.values)
        if (rule.avoid.contains(z.name)) z.name,
      if (rule.avoid.contains('centre')) 'centre',
    ];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.vastuRoomGuideTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.vastuRoomGuideHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _rooms.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final room = _rooms[i];
                return ChoiceChip(
                  label: Text(l10n.roomName(room)),
                  selected: room == _room,
                  onSelected: (_) => setState(() => _room = room),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: VastuChakra(
                  good: rule.ideal,
                  bad: rule.avoid,
                  maxSize: 130,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabelledLine(
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      label: l10n.vastuBestFor,
                      value: l10n.zoneList(ideal),
                    ),
                    if (avoid.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _LabelledLine(
                        icon: Icons.do_not_disturb_on_rounded,
                        color: AppColors.error,
                        label: l10n.vastuAvoid,
                        value: l10n.zoneList(avoid),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tip of the day

class _TipCard extends ConsumerWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tip = ref.watch(vastuTipProvider(ref.watch(appClockProvider)));

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.homeVastuTipOfTheDay,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tip.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tip.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          _LabelledLine(
            icon: Icons.explore_rounded,
            color: AppColors.primaryLight,
            label: l10n.homeVastuFocusArea,
            value: tip.direction,
          ),
          const SizedBox(height: 6),
          _LabelledLine(
            icon: Icons.task_alt_rounded,
            color: AppColors.success,
            label: l10n.homeVastuTodayAction,
            value: tip.action,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits

class _Panel extends StatelessWidget {
  final Widget child;
  final bool highlight;

  const _Panel({required this.child, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: highlight
              ? const [Color(0xFF232861), AppColors.background]
              : const [AppColors.surfaceLight, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.outline,
        ),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionTitle({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        ?action,
      ],
    );
  }
}

class _LabelledLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _LabelledLine({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
