import 'package:flutter/material.dart';

import '../../domain/entities/rashi_chart.dart';

class RashiChartWidget extends StatelessWidget {
  final RashiChart chart;

  const RashiChartWidget({
    super.key,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rashi Chart',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'North Indian • Whole Sign',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                return _HouseCell(
                  house: chart.house(index + 1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseCell extends StatelessWidget {
  final RashiHouse? house;

  const _HouseCell({
    required this.house,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'H${house?.house ?? '-'}',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(
            house?.sign ?? '',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (house != null && house!.planets.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              house!.planets.join(' • '),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}
