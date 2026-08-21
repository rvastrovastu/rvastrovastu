import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dasha_period.dart';
import '../providers/dasha_provider.dart';

class AntardashaTimeline extends ConsumerStatefulWidget {
  final DashaPeriod mahadasha;
  final DashaPeriod? currentAntardasha;
  final List<DashaPeriod> antardashas;

  const AntardashaTimeline({
    super.key,
    required this.mahadasha,
    required this.currentAntardasha,
    required this.antardashas,
  });

  @override
  ConsumerState<AntardashaTimeline> createState() => _AntardashaTimelineState();
}

class _AntardashaTimelineState extends ConsumerState<AntardashaTimeline> {
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _syncExpandedIndex();
  }

  @override
  void didUpdateWidget(covariant AntardashaTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentAntardasha != widget.currentAntardasha ||
        oldWidget.antardashas != widget.antardashas) {
      _syncExpandedIndex();
    }
  }

  void _syncExpandedIndex() {
    final currentIndex = widget.antardashas.indexWhere(
      (period) => period == widget.currentAntardasha,
    );

    _expandedIndex = currentIndex >= 0 ? currentIndex : null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.antardashas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Antardasha Timeline',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),

        const SizedBox(height: 4),

        Text(
          'Tap a period to explore its Pratyantardasha timeline.',
          style: Theme.of(context).textTheme.bodySmall,
        ),

        const SizedBox(height: 12),

        ...widget.antardashas.asMap().entries.map((entry) {
          final index = entry.key;
          final period = entry.value;
          final current = period == widget.currentAntardasha;
          final expanded = _expandedIndex == index;

          return _AntardashaSection(
            key: ValueKey('${period.planet.name}-${period.startDate}'),
            mahadasha: widget.mahadasha,
            period: period,
            current: current,
            expanded: expanded,
            onTap: () {
              setState(() {
                _expandedIndex = expanded ? null : index;
              });
            },
            pratyantardashas: expanded
                ? ref.watch(pratyantardashaTimelineProvider(period))
                : const <DashaPeriod>[],
          );
        }),
      ],
    );
  }
}

class _AntardashaSection extends StatelessWidget {
  final DashaPeriod mahadasha;
  final DashaPeriod period;
  final bool current;
  final bool expanded;
  final VoidCallback onTap;
  final List<DashaPeriod> pratyantardashas;

  const _AntardashaSection({
    super.key,
    required this.mahadasha,
    required this.period,
    required this.current,
    required this.expanded,
    required this.onTap,
    required this.pratyantardashas,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final progress = _progress(
      period.startDate,
      period.endDate,
      DateTime.now(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: current || expanded ? scheme.primary : theme.dividerColor,
          width: current || expanded ? 1.2 : 1,
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      current
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: current ? scheme.primary : null,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${mahadasha.planet.name} / '
                                  '${period.planet.name}',
                                  style: TextStyle(
                                    fontWeight: current
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),

                              if (current)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'ACTIVE',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          Text(
                            '${_formatDate(period.startDate)} → '
                            '${_formatDate(period.endDate)}',
                            style: theme.textTheme.bodySmall,
                          ),

                          const SizedBox(height: 8),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: scheme.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),

          if (expanded && pratyantardashas.isNotEmpty)
            _PratyantardashaTimeline(
              antardasha: period,
              periods: pratyantardashas,
            ),
        ],
      ),
    );
  }

  double _progress(DateTime start, DateTime end, DateTime now) {
    final total = end.difference(start).inMilliseconds;
    final elapsed = now.difference(start).inMilliseconds;

    if (total <= 0) {
      return 0;
    }

    return (elapsed / total).clamp(0.0, 1.0);
  }

  static String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _PratyantardashaTimeline extends StatelessWidget {
  final DashaPeriod antardasha;
  final List<DashaPeriod> periods;

  const _PratyantardashaTimeline({
    required this.antardasha,
    required this.periods,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(40, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),

          const SizedBox(height: 12),

          Text(
            'Pratyantardasha',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            'Nested periods within '
            '${antardasha.planet.name} Antardasha',
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: 10),

          ...periods.asMap().entries.map(
            (entry) => _PratyantardashaRow(
              period: entry.value,
              current: _isCurrent(entry.value, DateTime.now()),
              isLast: entry.key == periods.length - 1,
            ),
          ),
        ],
      ),
    );
  }

  bool _isCurrent(DashaPeriod period, DateTime now) {
    return !now.isBefore(period.startDate) && now.isBefore(period.endDate);
  }
}

class _PratyantardashaRow extends StatelessWidget {
  final DashaPeriod period;
  final bool current;
  final bool isLast;

  const _PratyantardashaRow({
    required this.period,
    required this.current,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: current ? scheme.primary : scheme.outlineVariant,
                  ),
                ),

                if (!isLast)
                  Expanded(
                    child: Container(width: 1, color: scheme.outlineVariant),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          period.planet.name,
                          style: TextStyle(
                            fontWeight: current
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Text(
                          '${_formatDate(period.startDate)} → '
                          '${_formatDate(period.endDate)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  if (current)
                    Text(
                      'NOW',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
