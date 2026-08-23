import 'package:flutter/material.dart';

import '../../../../astrology/domain/entities/rashi_chart.dart';
import 'planet_marker.dart';

class ChartHouse extends StatelessWidget {
  final RashiHouse house;
  final bool isLagna;

  const ChartHouse({
    super.key,
    required this.house,
    this.isLagna = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 3,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isLagna
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'H${house.house}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              height: 1.0,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            house.sign,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              height: 1.0,
              fontWeight: FontWeight.w700,
            ),
          ),

          if (house.planets.isNotEmpty) ...[
            const SizedBox(height: 3),

            Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 3,
              runSpacing: 1,
              children: house.planets
                  .map(
                    (planet) => PlanetMarker(
                      planet: planet.planet,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
