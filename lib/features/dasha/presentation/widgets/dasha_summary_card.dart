import 'package:flutter/material.dart';

import '../../domain/entities/dasha_period.dart';
import '../../domain/entities/dasha_timeline.dart';

class DashaSummaryCard extends StatelessWidget {
  final DashaTimeline timeline;
  final DashaPeriod? currentDasha;
  final DateTime? asOf;

  const DashaSummaryCard({
    super.key,
    required this.timeline,
    required this.currentDasha,
    this.asOf,
  });

  @override
  Widget build(BuildContext context) {
    final period = currentDasha;

    if (period == null) {
      return const SizedBox.shrink();
    }

    final referenceDate = asOf ?? DateTime.now();

    final totalSeconds = period.endDate
        .difference(period.startDate)
        .inSeconds
        .toDouble();

    final elapsedSeconds = referenceDate
        .difference(period.startDate)
        .inSeconds
        .toDouble();

    final progress = totalSeconds <= 0
        ? 0.0
        : (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);

    final remainingPercent = ((1 - progress) * 100).round();
    final elapsedPercent = (progress * 100).round();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline_outlined, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Current Vimshottari Dasha',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  child: Text(
                    period.planet.name.substring(0, 1),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        period.planet.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Mahadasha',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(period.startDate),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  _formatDate(period.endDate),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _infoItem(context, 'Elapsed', '$elapsedPercent%'),
                ),
                Expanded(
                  child: _infoItem(context, 'Remaining', '$remainingPercent%'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Mahadasha Timeline',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...timeline.periods.map(
              (item) => _timelineRow(context, item, item == period),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timelineRow(
    BuildContext context,
    DashaPeriod period,
    bool isCurrent,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            isCurrent
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              period.planet.name,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            _formatDate(period.startDate),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _infoItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
