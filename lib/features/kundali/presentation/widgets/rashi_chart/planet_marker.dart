import 'package:flutter/material.dart';

import '../../../../astrology/core/constants/planet_constants.dart';

class PlanetMarker extends StatelessWidget {
  final String planet;

  const PlanetMarker({
    super.key,
    required this.planet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      '${PlanetConstants.symbolFor(planet)} $planet',
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall?.copyWith(
        fontSize: 9,
        height: 1.0,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
