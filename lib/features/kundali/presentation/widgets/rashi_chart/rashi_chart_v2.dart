import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../astrology/domain/entities/rashi_chart.dart';
import '../../../../dosha/domain/entities/zodiac_signs.dart';
import 'chart_palette.dart';
import 'house_details_sheet.dart';
import 'planet_marker.dart';

/// Where a house's planets and sign number go in the North Indian chart,
/// as fractions of the chart's side.
class _Layout {
  /// Centre and size of the planet area.
  final Offset center;
  final Size box;

  /// Where the sign number sits, near the house's inner corner.
  final Offset number;

  const _Layout(this.center, this.box, this.number);
}

const _kendra = Size(0.32, 0.24);
const _top = Size(0.30, 0.13);
const _side = Size(0.14, 0.30);

/// Houses 1–12. Kendras are the four diamonds; the rest are triangles.
const _layouts = <_Layout>[
  _Layout(Offset(0.50, 0.25), _kendra, Offset(0.50, 0.43)), // 1
  _Layout(Offset(0.25, 0.085), _top, Offset(0.25, 0.20)), // 2
  _Layout(Offset(0.085, 0.25), _side, Offset(0.20, 0.25)), // 3
  _Layout(Offset(0.25, 0.50), _kendra, Offset(0.43, 0.50)), // 4
  _Layout(Offset(0.085, 0.75), _side, Offset(0.20, 0.75)), // 5
  _Layout(Offset(0.25, 0.915), _top, Offset(0.25, 0.80)), // 6
  _Layout(Offset(0.50, 0.75), _kendra, Offset(0.50, 0.57)), // 7
  _Layout(Offset(0.75, 0.915), _top, Offset(0.75, 0.80)), // 8
  _Layout(Offset(0.915, 0.75), _side, Offset(0.80, 0.75)), // 9
  _Layout(Offset(0.75, 0.50), _kendra, Offset(0.57, 0.50)), // 10
  _Layout(Offset(0.915, 0.25), _side, Offset(0.80, 0.25)), // 11
  _Layout(Offset(0.75, 0.085), _top, Offset(0.75, 0.20)), // 12
];

/// The house under point [p], given as fractions of the chart's side.
int northHouseAt(Offset p) {
  final x = p.dx, y = p.dy;
  if ((x - 0.5).abs() + (y - 0.5).abs() <= 0.5) {
    // Inside the inner diamond: one of the four kendras.
    final aboveMain = y < x; // above the top-left → bottom-right diagonal
    final aboveAnti = y < 1 - x; // above the bottom-left → top-right one
    if (aboveMain && aboveAnti) return 1;
    if (!aboveMain && !aboveAnti) return 7;
    return aboveAnti ? 4 : 10;
  }
  if (x < 0.5 && y < 0.5) return y < x ? 2 : 3;
  if (x >= 0.5 && y < 0.5) return y < 1 - x ? 12 : 11;
  if (x < 0.5) return y > 1 - x ? 6 : 5;
  return y > x ? 8 : 9;
}

/// North Indian (diamond) rashi chart. Houses are fixed with the Lagna at
/// the top; each house shows its sign number and its planets. Tap a house
/// for details.
class RashiChartV2 extends StatelessWidget {
  final RashiChart chart;

  /// When false, only the chart is drawn (the caller supplies headings).
  final bool showHeader;

  /// Whether tapping a house opens its details.
  final bool interactive;

  const RashiChartV2({
    super.key,
    required this.chart,
    this.showHeader = true,
    this.interactive = true,
  });

  RashiHouse _house(int number) =>
      chart.house(number) ??
      RashiHouse(house: number, sign: '—', planets: const []);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final diagram = AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          final font = chartFontSize(side);

          Widget at(Offset c, Size box, Widget child) => Positioned(
            left: (c.dx - box.width / 2) * side,
            top: (c.dy - box.height / 2) * side,
            width: box.width * side,
            height: box.height * side,
            child: child,
          );

          final children = <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _NorthChartPainter(
                  line: AppColors.primary.withValues(alpha: 0.55),
                  fill: AppColors.surfaceLight.withValues(alpha: 0.35),
                  lagna: AppColors.primary.withValues(alpha: 0.14),
                ),
              ),
            ),
          ];

          for (var n = 1; n <= 12; n++) {
            final layout = _layouts[n - 1];
            final house = _house(n);
            final signIndex = zodiacSignIndex(house.sign);

            children.add(
              at(
                layout.number,
                Size(0.08, font * 1.6 / side),
                Center(
                  child: Text(
                    signIndex < 0 ? '' : '${signIndex + 1}',
                    style: TextStyle(
                      fontSize: font * 0.85,
                      fontWeight: FontWeight.w700,
                      color: n == 1
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            );

            children.add(
              at(
                layout.center,
                layout.box,
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: layout.box.width * side,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (n == 1)
                            Text(
                              l10n.chartLagnaMark,
                              style: TextStyle(
                                fontSize: font * 0.8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: AppColors.primary,
                              ),
                            ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: font * 0.4,
                            runSpacing: 1,
                            children: [
                              for (final p in house.planets)
                                PlanetMarker(planet: p, fontSize: font),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          final stack = Stack(clipBehavior: Clip.none, children: children);
          if (!interactive) return stack;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => showHouseDetails(
              context,
              _house(
                northHouseAt(
                  Offset(
                    details.localPosition.dx / side,
                    details.localPosition.dy / side,
                  ),
                ),
              ),
            ),
            child: stack,
          );
        },
      ),
    );

    if (!showHeader) return diagram;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Text(
            l10n.chartD1,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
        ],
        diagram,
      ],
    );
  }
}

class _NorthChartPainter extends CustomPainter {
  final Color line;
  final Color fill;
  final Color lagna;

  const _NorthChartPainter({
    required this.line,
    required this.fill,
    required this.lagna,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset p(double x, double y) => Offset(x * s, y * s);

    final frame = RRect.fromRectAndRadius(
      Offset.zero & Size(s, s),
      Radius.circular(s * 0.025),
    );
    canvas.drawRRect(frame, Paint()..color = fill);

    // The Lagna diamond.
    canvas.drawPath(
      Path()
        ..moveTo(p(0.5, 0).dx, p(0.5, 0).dy)
        ..lineTo(p(0.75, 0.25).dx, p(0.75, 0.25).dy)
        ..lineTo(p(0.5, 0.5).dx, p(0.5, 0.5).dy)
        ..lineTo(p(0.25, 0.25).dx, p(0.25, 0.25).dy)
        ..close(),
      Paint()..color = lagna,
    );

    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s / 220).clamp(1.2, 2.2)
      ..strokeJoin = StrokeJoin.round;

    canvas.drawRRect(frame, stroke);
    canvas.drawLine(p(0, 0), p(1, 1), stroke);
    canvas.drawLine(p(1, 0), p(0, 1), stroke);
    canvas.drawPath(
      Path()
        ..moveTo(p(0.5, 0).dx, p(0.5, 0).dy)
        ..lineTo(p(1, 0.5).dx, p(1, 0.5).dy)
        ..lineTo(p(0.5, 1).dx, p(0.5, 1).dy)
        ..lineTo(p(0, 0.5).dx, p(0, 0.5).dy)
        ..close(),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _NorthChartPainter old) =>
      old.line != line || old.fill != fill || old.lagna != lagna;
}
