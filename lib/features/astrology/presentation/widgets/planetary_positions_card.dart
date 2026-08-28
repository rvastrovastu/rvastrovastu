import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../utils/astrology_localization.dart';

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
                context.l10n.planetaryPositions,
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
        context.l10n.planetName(planet.planet),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${context.l10n.rashiName(planet.sign)} • ${context.l10n.house} ${planet.house}',
      ),
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
            Text(context.l10n.retrograde, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
