import 'package:flutter/material.dart';

import '../../domain/entities/dasha_period.dart';
import '../../domain/entities/dasha_timeline.dart';

class DashaSummaryCard extends StatelessWidget {
  final DashaTimeline timeline;
  final DashaPeriod? currentDasha;
  final DashaPeriod? currentAntardasha;

  const DashaSummaryCard({
    super.key,
    required this.timeline,
    required this.currentDasha,
    this.currentAntardasha,
  });

  @override
  Widget build(BuildContext context) {
    if (currentDasha == null) {
      return const SizedBox.shrink();
    }

    final mahadasha = currentDasha!;
    final now = DateTime.now();

    final mahadashaProgress = _progress(
      mahadasha.startDate,
      mahadasha.endDate,
      now,
    );

    final antardashaProgress = currentAntardasha == null
        ? 0.0
        : _progress(
            currentAntardasha!.startDate,
            currentAntardasha!.endDate,
            now,
          );

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),

            const SizedBox(height: 20),

            _planetHeader(context, mahadasha, 'Mahadasha'),

            const SizedBox(height: 18),

            _progressBar(context, mahadashaProgress),

            const SizedBox(height: 10),

            _dateRange(context, mahadasha.startDate, mahadasha.endDate),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _infoItem(
                    context,
                    'Elapsed',
                    '${(mahadashaProgress * 100).toStringAsFixed(0)}%',
                  ),
                ),
                Expanded(
                  child: _infoItem(
                    context,
                    'Remaining',
                    '${((1 - mahadashaProgress) * 100).toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),

            if (currentAntardasha != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 18),

              Text(
                'Current Antardasha',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 14),

              _planetHeader(context, currentAntardasha!, 'Antardasha'),

              const SizedBox(height: 16),

              _progressBar(context, antardashaProgress),

              const SizedBox(height: 10),

              _dateRange(
                context,
                currentAntardasha!.startDate,
                currentAntardasha!.endDate,
              ),
            ],

            const SizedBox(height: 24),

            const Divider(),

            const SizedBox(height: 16),

            Text(
              'Dasha Timeline',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 12),

            ...timeline.periods.map(
              (period) => _timelineRow(context, period, period == mahadasha),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.timeline_outlined, size: 22),
        const SizedBox(width: 10),
        Text(
          'Current Vimshottari Dasha',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _planetHeader(
    BuildContext context,
    DashaPeriod period,
    String subtitle,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          child: Text(
            period.planet.name.substring(0, 1),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period.planet.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _progressBar(BuildContext context, double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(value: progress, minHeight: 8),
    );
  }

  Widget _dateRange(BuildContext context, DateTime start, DateTime end) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(_formatDate(start), style: Theme.of(context).textTheme.bodySmall),
        Text(_formatDate(end), style: Theme.of(context).textTheme.bodySmall),
      ],
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

  double _progress(DateTime start, DateTime end, DateTime now) {
    final total = end.difference(start).inMilliseconds;
    final elapsed = now.difference(start).inMilliseconds;

    if (total <= 0) {
      return 0;
    }

    return (elapsed / total).clamp(0.0, 1.0);
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
