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

                        // =================================================
                        // NORTH INDIAN CHART
                        //
                        //                 H2     H1     H12
                        //
                        //              H3           H11
                        //
                        //           H4                 H10
                        //
                        //           H5                 H9
                        //
                        //                 H6 H7 H8
                        //
                        // =================================================

                        // =================================================
                        // NORTH INDIAN CHART HOUSE CONTENT POSITIONS
                        //
                        //                  H2     H1     H12
                        //
                        //              H3             H11
                        //
                        //          H4                     H10
                        //
                        //              H5             H9
                        //
                        //                  H6 H7 H8
                        //
                        // Push perimeter houses toward the actual
                        // geometric regions of the diamond.
                        // =================================================

                        // =================================================
                        // NORTH INDIAN CHART — FINAL POSITION TUNING
                        //
                        //                 H2      H1      H12
                        //             H3                 H11
                        //          H4                       H10
                        //             H5                 H9
                        //                H6    H7    H8
                        //
                        // =================================================

                        // H1 — move UP
                        _house(
                          house: houses[0],
                          centerX: 0.50,
                          centerY: 0.37,
                          width: 0.30,
                          height: 0.24,
                        ),

                        // H2 — further upper-left
                        _house(
                          house: houses[1],
                          centerX: 0.13,
                          centerY: 0.045,
                          width: 0.30,
                          height: 0.18,
                        ),

                        // H3 — further upper-left
                        _house(
                          house: houses[2],
                          centerX: 0.035,
                          centerY: 0.21,
                          width: 0.18,
                          height: 0.24,
                        ),

                        // H4 — little RIGHT
                        _house(
                          house: houses[3],
                          centerX: 0.11,
                          centerY: 0.50,
                          width: 0.18,
                          height: 0.24,
                        ),

                        // H5 — further lower-left
                        _house(
                          house: houses[4],
                          centerX: 0.035,
                          centerY: 0.79,
                          width: 0.18,
                          height: 0.24,
                        ),

                        // H6 — further DOWN-left
                        _house(
                          house: houses[5],
                          centerX: 0.15,
                          centerY: 0.975,
                          width: 0.30,
                          height: 0.18,
                        ),

                        // H7 — further UP
                        _house(
                          house: houses[6],
                          centerX: 0.50,
                          centerY: 0.84,
                          width: 0.30,
                          height: 0.18,
                        ),

                        // H8 — further DOWN-right
                        _house(
                          house: houses[7],
                          centerX: 0.85,
                          centerY: 0.975,
                          width: 0.30,
                          height: 0.18,
                        ),

                        // H9 — further lower-right
                        _house(
                          house: houses[8],
                          centerX: 0.965,
                          centerY: 0.79,
                          width: 0.18,
                          height: 0.24,
                        ),

                        // H10 — little LEFT
                        _house(
                          house: houses[9],
                          centerX: 0.89,
                          centerY: 0.50,
                          width: 0.18,
                          height: 0.24,
                        ),

                        // H11 — further upper-right
                        _house(
                          house: houses[10],
                          centerX: 0.965,
                          centerY: 0.21,
                          width: 0.18,
                          height: 0.24,
                        ),

                        // H12 — further upper-right
                        _house(
                          house: houses[11],
                          centerX: 0.87,
                          centerY: 0.045,
                          width: 0.30,
                          height: 0.18,
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
    required double centerX,
    required double centerY,
    required double width,
    required double height,
  }) {
    return Positioned.fill(
      child: FractionallySizedBox(
        widthFactor: width,
        heightFactor: height,
        alignment: Alignment(
          centerX * 2 - 1,
          centerY * 2 - 1,
        ),
        child: ChartHouse(
          house: house,
          isLagna: house.house == 1,
        ),
      ),
    );
  }
}
