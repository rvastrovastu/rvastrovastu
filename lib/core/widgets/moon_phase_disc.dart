import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Canonical tithi names in calculation order (index 0–29), matching
/// `SwissEphemerisDailyPanchangRepository`.
const List<String> tithiNames = [
  'Shukla Pratipada',
  'Shukla Dwitiya',
  'Shukla Tritiya',
  'Shukla Chaturthi',
  'Shukla Panchami',
  'Shukla Shashthi',
  'Shukla Saptami',
  'Shukla Ashtami',
  'Shukla Navami',
  'Shukla Dashami',
  'Shukla Ekadashi',
  'Shukla Dwadashi',
  'Shukla Trayodashi',
  'Shukla Chaturdashi',
  'Purnima',
  'Krishna Pratipada',
  'Krishna Dwitiya',
  'Krishna Tritiya',
  'Krishna Chaturthi',
  'Krishna Panchami',
  'Krishna Shashthi',
  'Krishna Saptami',
  'Krishna Ashtami',
  'Krishna Navami',
  'Krishna Dashami',
  'Krishna Ekadashi',
  'Krishna Dwadashi',
  'Krishna Trayodashi',
  'Krishna Chaturdashi',
  'Amavasya',
];

/// Tithi index for a canonical name, or `null` if unknown (e.g. '—').
int? tithiIndexFromName(String name) {
  final index = tithiNames.indexOf(name.trim());
  return index < 0 ? null : index;
}

/// Draws the Moon as it looks during [tithiIndex]: waxing from the right
/// through Shukla paksha, full at Purnima, waning to dark at Amavasya.
class MoonPhaseDisc extends StatelessWidget {
  final int tithiIndex;
  final double size;

  const MoonPhaseDisc({super.key, required this.tithiIndex, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: MoonPhasePainter(tithiIndex)),
      ),
    );
  }
}

class MoonPhasePainter extends CustomPainter {
  final int tithiIndex;

  const MoonPhasePainter(this.tithiIndex);

  /// Sun–Moon elongation at the middle of the tithi, in degrees.
  double get elongation => (tithiIndex.clamp(0, 29) + 0.5) * 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 * 0.78;
    final disc = Rect.fromCircle(center: center, radius: radius);

    final illumination = (1 - math.cos(elongation * math.pi / 180)) / 2;

    // Soft halo, stronger as the Moon fills.
    canvas.drawCircle(
      center,
      radius * 1.22,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.10 + 0.25 * illumination),
            AppColors.accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.22)),
    );

    // Unlit Moon.
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF2A2F6E));

    // Lit portion: a semicircle on the sunward limb plus/minus an ellipse
    // whose half-width is |cos(elongation)| × radius.
    final waxing = elongation < 180;
    final terminatorWidth = radius * math.cos(elongation * math.pi / 180).abs();
    final gibbous = illumination > 0.5;

    final lit = Path()
      ..addArc(
        disc,
        waxing ? -math.pi / 2 : math.pi / 2,
        math.pi,
      );
    final ellipse = Path()
      ..addOval(
        Rect.fromCenter(
          center: center,
          width: terminatorWidth * 2,
          height: radius * 2,
        ),
      );

    final shape = gibbous
        ? Path.combine(PathOperation.union, lit, ellipse)
        : Path.combine(PathOperation.difference, lit, ellipse);

    canvas.save();
    canvas.clipPath(Path()..addOval(disc));
    canvas.drawPath(
      shape,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          colors: [Color(0xFFFFFBEF), AppColors.accent],
        ).createShader(disc),
    );
    canvas.restore();

    // Rim.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.accent.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant MoonPhasePainter oldDelegate) =>
      oldDelegate.tithiIndex != tithiIndex;
}
