// The Vastu tab's room-by-room guide, tip cards and small layout pieces.
part of 'vastu_tip_page.dart';

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
