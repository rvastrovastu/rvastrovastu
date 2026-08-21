import 'package:flutter/material.dart';

import '../../domain/entities/planet_position.dart';

class PlanetaryPositionsCard extends StatelessWidget {
  final List<PlanetPosition> planets;

  const PlanetaryPositionsCard({super.key, required this.planets});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Planetary Positions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          ...planets.map((planet) => _PlanetRow(planet: planet)),
        ],
      ),
    );
  }
}

class _PlanetRow extends StatelessWidget {
  final PlanetPosition planet;

  const _PlanetRow({required this.planet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        planet.planet,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${planet.sign} • House ${planet.house}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            planet.formattedDegree,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (planet.retrograde)
            Text('Retrograde', style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
