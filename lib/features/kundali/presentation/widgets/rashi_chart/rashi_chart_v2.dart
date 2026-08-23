import 'package:flutter/material.dart';

import '../../../../astrology/domain/entities/rashi_chart.dart';
import 'chart_house.dart';
import 'north_indian_chart_painter.dart';

class RashiChartV2 extends StatelessWidget {
  final RashiChart chart;

  const RashiChartV2({
    super.key,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final houses = List<RashiHouse>.generate(
      12,
      (index) =>
          chart.house(index + 1) ??
          RashiHouse(
            house: index + 1,
            sign: '—',
            planets: const [],
          ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rashi Chart',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'D1 • North Indian • Whole Sign',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest.shortestSide;

                return Center(
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: NorthIndianChartPainter(
                              lineColor: theme.colorScheme.outline
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ),

                        // -------------------------------------------------
                        // NORTH INDIAN CHART
                        //
                        //              H12 / H1 / H2
                        //           H11         H3
                        //          H10           H4
                        //           H9          H5
                        //              H8 H7 H6
                        //
                        // IMPORTANT:
                        // These are CONTENT positions, not square grid
                        // positions. The painter draws the actual diamond.
                        // -------------------------------------------------

                        _house(
                          house: houses[0],
                          x: 0.50,
                          y: 0.50,
                          width: 0.34,
                          height: 0.30,
                        ),

                        _house(
                          house: houses[1],
                          x: 0.25,
                          y: 0.13,
                          width: 0.30,
                          height: 0.24,
                        ),

                        _house(
                          house: houses[2],
                          x: 0.13,
                          y: 0.30,
                          width: 0.22,
                          height: 0.25,
                        ),

                        _house(
                          house: houses[3],
                          x: 0.13,
                          y: 0.50,
                          width: 0.22,
                          height: 0.30,
                        ),

                        _house(
                          house: houses[4],
                          x: 0.13,
                          y: 0.70,
                          width: 0.22,
                          height: 0.25,
                        ),

                        _house(
                          house: houses[5],
                          x: 0.25,
                          y: 0.87,
                          width: 0.30,
                          height: 0.24,
                        ),

                        _house(
                          house: houses[6],
                          x: 0.50,
                          y: 0.87,
                          width: 0.30,
                          height: 0.24,
                        ),

                        _house(
                          house: houses[7],
                          x: 0.75,
                          y: 0.87,
                          width: 0.30,
                          height: 0.24,
                        ),

                        _house(
                          house: houses[8],
                          x: 0.87,
                          y: 0.70,
                          width: 0.22,
                          height: 0.25,
                        ),

                        _house(
                          house: houses[9],
                          x: 0.87,
                          y: 0.50,
                          width: 0.22,
                          height: 0.30,
                        ),

                        _house(
                          house: houses[10],
                          x: 0.87,
                          y: 0.30,
                          width: 0.22,
                          height: 0.25,
                        ),

                        _house(
                          house: houses[11],
                          x: 0.75,
                          y: 0.13,
                          width: 0.30,
                          height: 0.24,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _house({
    required RashiHouse house,
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    return FractionalTranslation(
      translation: const Offset(-0.5, -0.5),
      child: Align(
        alignment: Alignment(
          (x * 2) - 1,
          (y * 2) - 1,
        ),
        child: FractionallySizedBox(
          widthFactor: width,
          heightFactor: height,
          child: IgnorePointer(
            child: ChartHouse(
              house: house,
              isLagna: house.house == 1,
            ),
          ),
        ),
      ),
    );
  }
}
