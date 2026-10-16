import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_extension.dart';
import '../../../../astrology/domain/entities/rashi_chart.dart';
import '../../../../astrology/presentation/utils/astrology_localization.dart';
import '../../../../dosha/domain/entities/zodiac_signs.dart';
import 'planet_marker.dart';

/// South Indian chart: signs are fixed in a 4×4 ring (Pisces top-left,
/// running clockwise), and the Lagna sign is marked with a diagonal.
class SouthIndianChart extends StatelessWidget {
  final RashiChart chart;

  const SouthIndianChart({super.key, required this.chart});

  /// (row, column) of each sign, Aries = 0.
  static const List<(int, int)> signCells = [
    (0, 1), // Aries
    (0, 2), // Taurus
    (0, 3), // Gemini
    (1, 3), // Cancer
    (2, 3), // Leo
    (3, 3), // Virgo
    (3, 2), // Libra
    (3, 1), // Scorpio
    (3, 0), // Sagittarius
    (2, 0), // Capricorn
    (1, 0), // Aquarius
    (0, 0), // Pisces
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = theme.colorScheme.outline;
    final lagna = chart.house(1);
    final lagnaIndex = lagna == null ? -1 : zodiacSignIndex(lagna.sign);

    RashiHouse? houseForSign(int signIndex) {
      for (final house in chart.houses) {
        if (zodiacSignIndex(house.sign) == signIndex) return house;
      }
      return null;
    }

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.biggest.shortestSide / 4;

          return Stack(
            children: [
              for (var sign = 0; sign < 12; sign++)
                Positioned(
                  left: signCells[sign].$2 * cell,
                  top: signCells[sign].$1 * cell,
                  width: cell,
                  height: cell,
                  child: _SignCell(
                    signIndex: sign,
                    house: houseForSign(sign),
                    isLagna: sign == lagnaIndex,
                    lineColor: line,
                  ),
                ),
              Positioned(
                left: cell,
                top: cell,
                width: cell * 2,
                height: cell * 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: line, width: 0.8),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.brightness_7_outlined,
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      size: cell * 0.5,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SignCell extends StatelessWidget {
  final int signIndex;
  final RashiHouse? house;
  final bool isLagna;
  final Color lineColor;

  const _SignCell({
    required this.signIndex,
    required this.house,
    required this.isLagna,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return CustomPaint(
      foregroundPainter: isLagna
          ? _LagnaMarkPainter(theme.colorScheme.primary)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: isLagna
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : null,
          border: Border.all(color: lineColor, width: 0.8),
        ),
        padding: const EdgeInsets.all(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.rashiName(zodiacSigns[signIndex]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                height: 1.0,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (isLagna)
              Text(
                l10n.chartLagnaMark,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            const SizedBox(height: 2),
            Expanded(
              child: Wrap(
                spacing: 3,
                runSpacing: 1,
                children: [
                  for (final planet in house?.planets ?? const [])
                    PlanetMarker(planet: planet.planet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The traditional diagonal stroke across the Lagna cell's corner.
class _LagnaMarkPainter extends CustomPainter {
  final Color color;

  const _LagnaMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * 0.72, 0),
      Offset(size.width, size.height * 0.28),
      Paint()
        ..color = color
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _LagnaMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
