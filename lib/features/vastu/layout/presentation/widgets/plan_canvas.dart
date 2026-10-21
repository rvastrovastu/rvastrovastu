import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/vastu_zone.dart';
import '../../domain/vastu_analysis.dart';
import '../../domain/vastu_layout.dart';

/// Ray from [from] at image angle [degrees] (clockwise from up) to the edge
/// of [rect].
Offset rayToRect(Offset from, double degrees, Rect rect) {
  final a = degrees * math.pi / 180;
  final d = Offset(math.sin(a), -math.cos(a));
  var t = double.infinity;
  if (d.dx > 1e-9) t = math.min(t, (rect.right - from.dx) / d.dx);
  if (d.dx < -1e-9) t = math.min(t, (rect.left - from.dx) / d.dx);
  if (d.dy > 1e-9) t = math.min(t, (rect.bottom - from.dy) / d.dy);
  if (d.dy < -1e-9) t = math.min(t, (rect.top - from.dy) / d.dy);
  if (!t.isFinite) t = 0;
  return from + d * t;
}

/// The plan image with the house outline, compass grid and markers on top.
class PlanCanvas extends StatelessWidget {
  final VastuLayout layout;

  /// The plan image file, or null for a blank square.
  final File? image;

  /// Full 16-zone grid with labels; otherwise only the north arrow.
  final bool showGrid;

  /// Room fit colours from an analysis; plain markers when null.
  final Map<String, ZoneFit>? fits;

  /// Called with the tapped spot, as fractions of the image size.
  final ValueChanged<PlanPoint>? onTap;

  const PlanCanvas({
    super.key,
    required this.layout,
    this.image,
    this.showGrid = false,
    this.fits,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: layout.aspectRatio,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          Offset px(PlanPoint p) =>
              Offset(p.x * size.width, p.y * size.height);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onTap == null
                ? null
                : (d) => onTap!(
                    PlanPoint(
                      (d.localPosition.dx / size.width).clamp(0.0, 1.0),
                      (d.localPosition.dy / size.height).clamp(0.0, 1.0),
                    ),
                  ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: image == null
                        ? const ColoredBox(color: Color(0xFFF4EFE6))
                        : Image.file(image!, fit: BoxFit.fill),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: PlanGridPainter(
                        layout: layout,
                        showGrid: showGrid,
                        labelStyle: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  if (layout.entrance case final door?)
                    _marker(
                      px(door),
                      const Icon(
                        Icons.door_front_door,
                        size: 16,
                        color: Colors.white,
                      ),
                      AppColors.primary,
                    ),
                  for (final mark in layout.rooms)
                    _marker(
                      px(mark.at),
                      Icon(
                        roomIcon(mark.room),
                        size: 15,
                        color: Colors.white,
                      ),
                      switch (fits?[mark.id]) {
                        ZoneFit.ideal => AppColors.success,
                        ZoneFit.acceptable => const Color(0xFFD08A00),
                        ZoneFit.avoid => AppColors.error,
                        null => const Color(0xFF5B4B8A),
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _marker(Offset at, Widget icon, Color color) => Positioned(
    left: at.dx - 13,
    top: at.dy - 13,
    child: IgnorePointer(
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
        ),
        child: Center(child: icon),
      ),
    ),
  );
}

IconData roomIcon(VastuRoom room) => switch (room) {
  VastuRoom.kitchen => Icons.soup_kitchen_outlined,
  VastuRoom.masterBedroom => Icons.king_bed_outlined,
  VastuRoom.bedroom => Icons.bed_outlined,
  VastuRoom.childrenRoom => Icons.child_care_outlined,
  VastuRoom.guestRoom => Icons.single_bed_outlined,
  VastuRoom.living => Icons.weekend_outlined,
  VastuRoom.dining => Icons.dining_outlined,
  VastuRoom.pooja => Icons.temple_hindu_outlined,
  VastuRoom.study => Icons.menu_book_outlined,
  VastuRoom.office => Icons.work_outline,
  VastuRoom.toilet => Icons.wc_outlined,
  VastuRoom.bathroom => Icons.bathtub_outlined,
  VastuRoom.store => Icons.inventory_2_outlined,
  VastuRoom.staircase => Icons.stairs_outlined,
  VastuRoom.undergroundWater => Icons.water_outlined,
  VastuRoom.overheadTank => Icons.water_drop_outlined,
  VastuRoom.septicTank => Icons.delete_outline,
  VastuRoom.parking => Icons.directions_car_outlined,
  VastuRoom.cashLocker => Icons.lock_outline,
  VastuRoom.openSpace => Icons.park_outlined,
};

/// Draws the house outline, the Brahmasthan and either the 16-zone grid or
/// a north arrow.
class PlanGridPainter extends CustomPainter {
  final VastuLayout layout;
  final bool showGrid;
  final TextStyle? labelStyle;

  PlanGridPainter({
    required this.layout,
    required this.showGrid,
    this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final f = layout.frame;
    final rect = Rect.fromLTRB(
      f.left * size.width,
      f.top * size.height,
      f.right * size.width,
      f.bottom * size.height,
    );
    final centre = rect.center;
    const ink = Color(0xFF8A5A00);

    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ink,
    );

    final brahma = Rect.fromCenter(
      center: centre,
      width: rect.width / 3,
      height: rect.height / 3,
    );
    canvas.drawRect(brahma, Paint()..color = ink.withValues(alpha: 0.08));
    canvas.drawRect(
      brahma,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ink.withValues(alpha: 0.5),
    );

    if (showGrid) {
      final line = Paint()
        ..strokeWidth = 1
        ..color = ink.withValues(alpha: 0.6);
      for (final zone in VastuZone.values) {
        final end = rayToRect(
          centre,
          layout.imageAngleOf(zone.startBearing),
          rect,
        );
        canvas.drawLine(centre, end, line);
      }
      for (final zone in VastuZone.values) {
        final edge = rayToRect(
          centre,
          layout.imageAngleOf(zone.centre),
          rect,
        );
        final at = Offset.lerp(centre, edge, 0.78)!;
        _label(canvas, zone.abbreviation, at, zone == VastuZone.n);
      }
    }

    // North arrow from the centre.
    final north = rayToRect(centre, layout.imageAngleOf(0), rect);
    final tip = Offset.lerp(centre, north, showGrid ? 0.55 : 0.8)!;
    final arrow = Paint()
      ..strokeWidth = 2.5
      ..color = AppColors.error
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(centre, tip, arrow);
    final dir = (tip - centre) / math.max((tip - centre).distance, 1);
    final side = Offset(-dir.dy, dir.dx);
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - dir.dx * 10 + side.dx * 6,
        tip.dy - dir.dy * 10 + side.dy * 6,
      )
      ..lineTo(
        tip.dx - dir.dx * 10 - side.dx * 6,
        tip.dy - dir.dy * 10 - side.dy * 6,
      )
      ..close();
    canvas.drawPath(head, Paint()..color = AppColors.error);
    if (!showGrid) _label(canvas, 'N', tip + dir * 12, true);
  }

  void _label(Canvas canvas, String text, Offset at, bool strong) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: (labelStyle ?? const TextStyle(fontSize: 11)).copyWith(
          fontWeight: FontWeight.w800,
          color: strong ? AppColors.error : const Color(0xFF5A3C00),
          backgroundColor: Colors.white.withValues(alpha: 0.75),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(PlanGridPainter old) =>
      old.layout != layout || old.showGrid != showGrid;
}
