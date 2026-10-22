import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_extension.dart';
import '../../../../astrology/domain/entities/planet_position.dart';
import 'chart_palette.dart';

/// A planet in a chart cell: short name in its colour, its degree in the
/// sign, and a mark when retrograde.
class PlanetMarker extends StatelessWidget {
  final PlanetPosition planet;
  final double fontSize;

  const PlanetMarker({super.key, required this.planet, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = planetColor(planet.planet);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: l10n.planetShort(planet.planet),
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
          TextSpan(
            text: ' ${planet.degree.floor()}°',
            style: TextStyle(
              fontSize: fontSize * 0.78,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          if (planet.retrograde)
            TextSpan(
              text: ' ${l10n.chartRetroShort}',
              style: TextStyle(
                fontSize: fontSize * 0.72,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      style: TextStyle(fontSize: fontSize, height: 1.15),
    );
  }
}
