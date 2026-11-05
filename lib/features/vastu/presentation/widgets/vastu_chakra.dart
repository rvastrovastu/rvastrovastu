import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/vastu_zone.dart';

/// The five elements of the Vastu Purusha mandala: water in the
/// north-east (Ishanya), fire in the south-east (Agni), earth in the
/// south-west (Nairutya), air in the north-west (Vayu) and space at the
/// centre (Brahmasthan).
enum VastuElement { water, fire, earth, air, space }

extension VastuElementColor on VastuElement {
  Color get color => switch (this) {
    VastuElement.water => const Color(0xFF5AA9E6),
    VastuElement.fire => const Color(0xFFE8794A),
    VastuElement.earth => const Color(0xFFD4A64A),
    VastuElement.air => const Color(0xFF8FD0B5),
    VastuElement.space => const Color(0xFFB59BE0),
  };
}

/// The element of the corner a zone leans towards; null for the four
/// cardinal zones, which sit between two corners.
VastuElement? elementOfZone(VastuZone zone) => switch (zone) {
  VastuZone.nne || VastuZone.ne || VastuZone.ene => VastuElement.water,
  VastuZone.ese || VastuZone.se || VastuZone.sse => VastuElement.fire,
  VastuZone.ssw || VastuZone.sw || VastuZone.wsw => VastuElement.earth,
  VastuZone.wnw || VastuZone.nw || VastuZone.nnw => VastuElement.air,
  VastuZone.n || VastuZone.e || VastuZone.s || VastuZone.w => null,
};

/// A tappable 16-zone Vastu wheel with North at the top.
///
/// By default each zone is tinted by its element. Pass [good] and [bad]
/// zone keys to colour it as a placement guide instead (green suits,
/// red avoid).
class VastuChakra extends StatelessWidget {
  final VastuZone? selected;
  final ValueChanged<VastuZone>? onSelect;
  final Set<String>? good;
  final Set<String>? bad;
  final double maxSize;

  const VastuChakra({
    super.key,
    this.selected,
    this.onSelect,
    this.good,
    this.bad,
    this.maxSize = 300,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall!;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxSize),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: onSelect == null
                    ? null
                    : (details) {
                        final zone = zoneAt(details.localPosition, size);
                        if (zone != null) onSelect!(zone);
                      },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: size,
                      painter: VastuChakraPainter(
                        selected: selected,
                        good: good,
                        bad: bad,
                        labelStyle: labelStyle,
                      ),
                    ),
                    Icon(
                      Icons.home_rounded,
                      size: size.shortestSide * 0.11,
                      color: VastuElement.space.color,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The zone under [position], or null in the centre or outside.
  static VastuZone? zoneAt(Offset position, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 * VastuChakraPainter.outer;
    final d = position - center;
    final distance = d.distance;
    if (distance < radius * VastuChakraPainter.inner || distance > radius) {
      return null;
    }
    final bearing = math.atan2(d.dx, -d.dy) * 180 / math.pi;
    return vastuZoneForHeading(bearing);
  }
}

class VastuChakraPainter extends CustomPainter {
  /// Wheel radius as a share of half the size, leaving room for the
  /// North marker.
  static const outer = 0.92;

  /// Inner (Brahmasthan) circle as a share of the wheel radius.
  static const inner = 0.3;

  final VastuZone? selected;
  final Set<String>? good;
  final Set<String>? bad;
  final TextStyle labelStyle;

  const VastuChakraPainter({
    required this.selected,
    required this.good,
    required this.bad,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 * outer;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const sweep = 2 * math.pi / 16;
    final guide = good != null || bad != null;

    // Soft glow behind the wheel.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    for (final zone in VastuZone.values) {
      final start = (zone.centre - 11.25 - 90) * math.pi / 180;
      final isSelected = zone == selected;

      Color fill;
      if (guide) {
        fill = good?.contains(zone.name) ?? false
            ? AppColors.success.withValues(alpha: 0.55)
            : bad?.contains(zone.name) ?? false
            ? AppColors.error.withValues(alpha: 0.45)
            : AppColors.surfaceLight;
      } else {
        final element = elementOfZone(zone);
        fill = element == null
            ? AppColors.primary.withValues(alpha: isSelected ? 0.5 : 0.16)
            : element.color.withValues(alpha: isSelected ? 0.6 : 0.24);
      }
      canvas.drawArc(rect, start, sweep, true, Paint()..color = fill);
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.background.withValues(alpha: 0.8),
      );

      // Labels stay upright.
      final mid = start + sweep / 2;
      final major = zone.index % 4 == 0;
      final painter = TextPainter(
        text: TextSpan(
          text: zone.abbreviation,
          style: labelStyle.copyWith(
            color: isSelected
                ? AppColors.textPrimary
                : major
                ? AppColors.primaryLight
                : AppColors.textSecondary,
            fontWeight: major || isSelected
                ? FontWeight.w800
                : FontWeight.w600,
            fontSize: major ? 13 : 9.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final at = Offset(
        center.dx + math.cos(mid) * radius * 0.76,
        center.dy + math.sin(mid) * radius * 0.76,
      );
      painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
    }

    // Selected zone outline on top.
    if (selected case final zone?) {
      final start = (zone.centre - 11.25 - 90) * math.pi / 180;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = AppColors.primary,
      );
    }

    // Outer rim.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.primary.withValues(alpha: 0.7),
    );

    // Brahmasthan.
    final hub = radius * inner;
    canvas.drawCircle(center, hub, Paint()..color = AppColors.background);
    canvas.drawCircle(
      center,
      hub,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = VastuElement.space.color.withValues(alpha: 0.8),
    );

    // North marker.
    final tip = Offset(center.dx, center.dy - radius - 2);
    final marker = Path()
      ..moveTo(tip.dx, tip.dy - 10)
      ..lineTo(tip.dx - 7, tip.dy + 2)
      ..lineTo(tip.dx + 7, tip.dy + 2)
      ..close();
    canvas.drawPath(marker, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant VastuChakraPainter old) =>
      old.selected != selected || old.good != good || old.bad != bad;
}
