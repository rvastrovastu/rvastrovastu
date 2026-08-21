import 'package:flutter/material.dart';

import '../../domain/entities/dasha_period.dart';
import '../../domain/entities/dasha_timeline.dart';
import 'antardasha_timeline.dart';

class DashaSummaryCard extends StatelessWidget {
  final DashaTimeline timeline;
  final DashaPeriod? currentDasha;
  final DashaPeriod? currentAntardasha;
  final List<DashaPeriod> antardashas;

  const DashaSummaryCard({
    super.key,
    required this.timeline,
    this.currentDasha,
    this.currentAntardasha,
    this.antardashas = const [],
  });

  @override
  Widget build(BuildContext context) {
    final mahadasha = currentDasha;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vimshottari Dasha',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 16),

            if (mahadasha != null) ...[
              Text(
                'Current Mahadasha',
                style: Theme.of(context).textTheme.labelLarge,
              ),

              const SizedBox(height: 6),

              Text(
                mahadasha.planet.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '${_formatDate(mahadasha.startDate)} → '
                '${_formatDate(mahadasha.endDate)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 20),

              AntardashaTimeline(
                mahadasha: mahadasha,
                currentAntardasha: currentAntardasha,
                antardashas: antardashas,
              ),
            ] else ...[
              Text(
                'Current Dasha unavailable',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],

            const SizedBox(height: 20),

            Text(
              'Mahadasha Timeline',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 12),

            ...timeline.periods.map(
              (period) => _timelineRow(context, period, period == currentDasha),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timelineRow(BuildContext context, DashaPeriod period, bool current) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: current
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 18,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.planet.name,
                  style: TextStyle(
                    fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(period.startDate)} → '
                  '${_formatDate(period.endDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
