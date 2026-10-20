import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A quiet night-sky backdrop: an indigo gradient with a fixed, seeded
/// starfield. Static on purpose — it should feel like a place, not an
/// animation competing with the content.
class CelestialBackground extends StatelessWidget {
  final Widget child;

  /// Fraction of the height the stars cover from the top; the rest fades
  /// to the plain background so long content stays readable.
  final double starCoverage;

  const CelestialBackground({
    super.key,
    required this.child,
    this.starCoverage = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1D57), AppColors.background],
          stops: [0, 0.45],
        ),
      ),
      child: CustomPaint(
        painter: StarfieldPainter(coverage: starCoverage),
        child: child,
      ),
    );
  }
}

class StarfieldPainter extends CustomPainter {
  final double coverage;
  final int seed;
  final int count;

  const StarfieldPainter({
    this.coverage = 0.55,
    this.seed = 108,
    this.count = 90,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final random = math.Random(seed);
    final height = size.height * coverage;
    final paint = Paint();

    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      // Bias stars toward the top so they thin out as content begins.
      final y = math.pow(random.nextDouble(), 1.6) * height;
      final fade = 1 - (y / height);
      final radius = 0.4 + random.nextDouble() * 1.1;
      final alpha = (0.15 + random.nextDouble() * 0.55) * fade;

      paint.color = AppColors.accent.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y.toDouble()), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) =>
      oldDelegate.coverage != coverage ||
      oldDelegate.seed != seed ||
      oldDelegate.count != count;
}
