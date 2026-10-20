import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_extension.dart';
import '../../../../astrology/presentation/utils/astrology_localization.dart';

import '../../../../astrology/core/constants/planet_constants.dart';

class PlanetMarker extends StatelessWidget {
  final String planet;

  const PlanetMarker({super.key, required this.planet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      '${PlanetConstants.symbolFor(planet)} ${context.l10n.planetName(planet)}',
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
