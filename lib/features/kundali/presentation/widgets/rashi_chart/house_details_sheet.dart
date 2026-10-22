import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../astrology/domain/entities/rashi_chart.dart';
import '../../../../astrology/presentation/utils/astrology_localization.dart';
import 'chart_palette.dart';

/// Bottom sheet with a house's sign and each planet in it.
Future<void> showHouseDetails(BuildContext context, RashiHouse house) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => HouseDetails(house: house),
    );

class HouseDetails extends StatelessWidget {
  final RashiHouse house;

  const HouseDetails({super.key, required this.house});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.chartHouseTitle(house.house, l10n.rashiName(house.sign)),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (house.planets.isEmpty)
              Text(l10n.chartHouseEmpty, style: theme.textTheme.bodyMedium)
            else
              for (final p in house.planets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: planetColor(p.planet).withValues(alpha: 0.15),
                          border: Border.all(color: planetColor(p.planet)),
                        ),
                        child: Text(
                          l10n.planetShort(p.planet),
                          style: TextStyle(
                            color: planetColor(p.planet),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                l10n.planetName(p.planet),
                                if (p.retrograde) l10n.retrograde,
                              ].join(' · '),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              [
                                _degree(p.degree),
                                if (p.nakshatra != null)
                                  p.nakshatraPada == null
                                      ? l10n.nakshatraName(p.nakshatra!)
                                      : '${l10n.nakshatraName(p.nakshatra!)} '
                                            '(${p.nakshatraPada})',
                              ].join(' · '),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static String _degree(double degree) {
    final d = degree.floor();
    final m = ((degree - d) * 60).floor();
    return '$d° ${m.toString().padLeft(2, '0')}′';
  }
}
