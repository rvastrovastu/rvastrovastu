import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../astrology/domain/entities/rashi_chart.dart';
import '../../../../astrology/presentation/utils/astrology_localization.dart';
import '../../../../dosha/domain/entities/zodiac_signs.dart';
import 'chart_palette.dart';
import 'house_details_sheet.dart';
import 'planet_marker.dart';

/// South Indian chart: signs are fixed in a 4×4 ring (Pisces top-left,
/// running clockwise), and the Lagna sign is marked with a diagonal. Tap
/// a sign for details.
class SouthIndianChart extends StatelessWidget {
  final RashiChart chart;
  final bool interactive;

  const SouthIndianChart({
    super.key,
    required this.chart,
    this.interactive = true,
  });

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
    final l10n = context.l10n;
    final line = AppColors.primary.withValues(alpha: 0.5);
    final lagna = chart.house(1);
    final lagnaIndex = lagna == null ? -1 : zodiacSignIndex(lagna.sign);

    RashiHouse? houseForSign(int signIndex) {
      for (final house in chart.houses) {
        if (zodiacSignIndex(house.sign) == signIndex) return house;
      }
      return null;
    }

    final diagram = AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          final cell = side / 4;
          final font = chartFontSize(side, factor: 0.034);

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(side * 0.02),
                  ),
                ),
              ),
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
                    fontSize: font,
                    onTap: !interactive
                        ? null
                        : () {
                            final house = houseForSign(sign);
                            if (house != null) showHouseDetails(context, house);
                          },
                  ),
                ),
              Positioned(
                left: cell,
                top: cell,
                width: cell * 2,
                height: cell * 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: line, width: 1.2),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.brightness_7_outlined,
                          color: AppColors.primary.withValues(alpha: 0.45),
                          size: cell * 0.45,
                        ),
                        if (lagna != null) ...[
                          SizedBox(height: font * 0.4),
                          Text(
                            '${l10n.chartLagnaMark}: '
                            '${l10n.rashiName(lagna.sign)}',
                            style: TextStyle(
                              fontSize: font,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return diagram;
  }
}

class _SignCell extends StatelessWidget {
  final int signIndex;
  final RashiHouse? house;
  final bool isLagna;
  final Color lineColor;
  final double fontSize;
  final VoidCallback? onTap;

  const _SignCell({
    required this.signIndex,
    required this.house,
    required this.isLagna,
    required this.lineColor,
    required this.fontSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: isLagna ? _LagnaMarkPainter(AppColors.primary) : null,
        child: Container(
          decoration: BoxDecoration(
            color: isLagna ? AppColors.primary.withValues(alpha: 0.14) : null,
            border: Border.all(color: lineColor, width: 0.8),
          ),
          padding: EdgeInsets.all(fontSize * 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.rashiName(zodiacSigns[signIndex]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize * 0.8,
                  height: 1.1,
                  fontWeight: isLagna ? FontWeight.w700 : FontWeight.w500,
                  color: isLagna ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              SizedBox(height: fontSize * 0.2),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final planet in house?.planets ?? const [])
                          PlanetMarker(planet: planet, fontSize: fontSize),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _LagnaMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
