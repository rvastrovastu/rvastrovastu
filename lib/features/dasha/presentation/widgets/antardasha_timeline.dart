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
    _syncCurrent();
  }

  @override
  void didUpdateWidget(covariant AntardashaTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentAntardasha != widget.currentAntardasha ||
        oldWidget.antardashas != widget.antardashas) {
      _syncCurrent();
    }
  }

  void _syncCurrent() {
    final index = widget.antardashas.indexWhere(
      (period) => period == widget.currentAntardasha,
    );

    _expandedIndex = index >= 0 ? index : null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.antardashas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Antardasha Timeline',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 12),

        ...widget.antardashas.asMap().entries.map((entry) {
          final index = entry.key;
          final period = entry.value;

          final isCurrent = period == widget.currentAntardasha;

          final isExpanded = _expandedIndex == index;

          final pratyantardashas = isExpanded
              ? ref.watch(pratyantardashaTimelineProvider(period))
              : const <DashaPeriod>[];

          return _AntardashaRow(
            key: ValueKey('${period.planet.name}-${period.startDate}'),
            mahadasha: widget.mahadasha,
            period: period,
            isCurrent: isCurrent,
            isExpanded: isExpanded,
            pratyantardashas: pratyantardashas,
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
          );
        }),
      ],
    );
  }
}

class _AntardashaRow extends StatelessWidget {
  final DashaPeriod mahadasha;
  final DashaPeriod period;
  final bool isCurrent;
  final bool isExpanded;
  final List<DashaPeriod> pratyantardashas;
  final VoidCallback onTap;

  const _AntardashaRow({
    super.key,
    required this.mahadasha,
    required this.period,
    required this.isCurrent,
    required this.isExpanded,
    required this.pratyantardashas,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent ? scheme.primary.withValues(alpha: 0.06) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? scheme.primary : theme.dividerColor,
          width: isCurrent ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      isCurrent
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: isCurrent ? scheme.primary : null,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        '${mahadasha.planet.name} / '
                        '${period.planet.name}',
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ),

                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
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

                    const SizedBox(width: 6),

                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (isExpanded && pratyantardashas.isNotEmpty)
            _PratyantardashaTimeline(
              antardasha: period,
              periods: pratyantardashas,
            ),
        ],
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(40, 0, 14, 14),
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

          const SizedBox(height: 8),

          ...periods.asMap().entries.map((entry) {
            final period = entry.value;

            return _PratyantardashaRow(
              period: period,
              current: period.contains(DateTime.now()),
              isLast: entry.key == periods.length - 1,
            );
          }),
        ],
      ),
    );
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
            width: 18,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 8,
                  height: 8,
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
                                : FontWeight.w500,
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
