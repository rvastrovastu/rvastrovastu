import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/vastu_zone.dart';
import '../providers/compass_provider.dart';

class VastuCompassPage extends ConsumerStatefulWidget {
  const VastuCompassPage({super.key});

  @override
  ConsumerState<VastuCompassPage> createState() => _VastuCompassPageState();
}

class _VastuCompassPageState extends ConsumerState<VastuCompassPage> {
  /// Heading frozen by "Hold reading", or null while live.
  double? _held;

  /// Unwrapped heading so the wheel turns the short way across North.
  double _continuous = 0;
  double? _lastRaw;

  double _unwrap(double raw) {
    final last = _lastRaw;
    if (last == null) {
      _continuous = raw;
    } else {
      var delta = raw - last;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      _continuous += delta;
    }
    _lastRaw = raw;
    return _continuous;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final headingAsync = ref.watch(compassHeadingProvider);

    final live = headingAsync.value;
    final heading = _held ?? live;
    final zone = heading == null ? null : vastuZoneForHeading(heading);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vastuCompassTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(l10n.vastuCompassHowTo, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (headingAsync.isLoading && heading == null)
            const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (heading == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.explore_off_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.vastuCompassNoSensor)),
                  ],
                ),
              ),
            )
          else ...[
            _CompassDial(
              heading: _held == null ? _unwrap(heading) : _continuous,
              activeZone: zone!,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                l10n.vastuZoneName(zone.name),
                style: theme.textTheme.headlineSmall,
              ),
            ),
            Center(
              child: Text(
                '${heading.round()}° · ${zone.abbreviation}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(
                  () => _held = _held == null ? live : null,
                ),
                icon: Icon(
                  _held == null ? Icons.pause_outlined : Icons.play_arrow,
                ),
                label: Text(
                  _held == null
                      ? l10n.vastuCompassHold
                      : l10n.vastuCompassResume,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ZoneCard(zone: zone),
          ],
          const SizedBox(height: 20),
          Text(l10n.vastuAllZones, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final z in VastuZone.values)
                  ExpansionTile(
                    leading: SizedBox(
                      width: 40,
                      child: Text(
                        z.abbreviation,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: z == zone ? AppColors.primary : null,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(l10n.vastuZoneName(z.name)),
                    subtitle: Text(l10n.vastuZoneTheme(z.name)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [_ZoneDetails(zone: z)],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.vastuCompassDisclaimer,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  final VastuZone zone;

  const _ZoneCard({required this.zone});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.vastuZoneTheme(zone.name),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _ZoneDetails(zone: zone),
          ],
        ),
      ),
    );
  }
}

class _ZoneDetails extends StatelessWidget {
  final VastuZone zone;

  const _ZoneDetails({required this.zone});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget row(IconData icon, Color color, String label, String value) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$label: ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: value),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(
          Icons.check_circle_outline,
          AppColors.success,
          l10n.vastuBestFor,
          l10n.vastuZoneBest(zone.name),
        ),
        row(
          Icons.do_not_disturb_on_outlined,
          AppColors.error,
          l10n.vastuAvoid,
          l10n.vastuZoneAvoid(zone.name),
        ),
      ],
    );
  }
}

class _CompassDial extends StatelessWidget {
  final double heading;
  final VastuZone activeZone;

  const _CompassDial({required this.heading, required this.activeZone});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // Capped so the zone name below stays on screen on large phones and
    // tablets.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: heading),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                builder: (context, value, _) => CustomPaint(
                  size: Size.infinite,
                  painter: CompassWheelPainter(
                    heading: value,
                    activeZone: activeZone,
                    labelStyle: Theme.of(context).textTheme.labelSmall!,
                  ),
                ),
              ),
              // Fixed pointer: where the top of the phone points.
              const Align(
                alignment: Alignment.topCenter,
                child: Icon(
                  Icons.arrow_drop_down,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sixteen-zone wheel rotated so the zone the phone points at is on top.
class CompassWheelPainter extends CustomPainter {
  final double heading;
  final VastuZone activeZone;
  final TextStyle labelStyle;

  const CompassWheelPainter({
    required this.heading,
    required this.activeZone,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 * 0.86;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const sweep = 2 * math.pi / 16;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);

    for (final zone in VastuZone.values) {
      // Canvas angle 0 is East; compass 0 is North (−90° on canvas).
      final start = (zone.centre - 11.25 - 90) * math.pi / 180;
      final isActive = zone == activeZone;
      final fill = Paint()
        ..color = isActive
            ? AppColors.primary.withValues(alpha: 0.30)
            : zone.index.isEven
            ? AppColors.surfaceLight
            : AppColors.surface;
      canvas.drawArc(rect, start, sweep, true, fill);
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = AppColors.outline,
      );

      final mid = start + sweep / 2;
      final labelOffset = Offset(
        center.dx + math.cos(mid) * radius * 0.80,
        center.dy + math.sin(mid) * radius * 0.80,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: zone.abbreviation,
          style: labelStyle.copyWith(
            color: zone == VastuZone.n
                ? AppColors.primary
                : isActive
                ? AppColors.textPrimary
                : AppColors.textSecondary,
            fontWeight: zone.index % 4 == 0
                ? FontWeight.w800
                : FontWeight.w500,
            fontSize: zone.index % 4 == 0 ? 13 : 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Keep labels upright relative to the wheel's own North.
      canvas.save();
      canvas.translate(labelOffset.dx, labelOffset.dy);
      canvas.rotate(mid + math.pi / 2);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }

    canvas.restore();

    // Centre: Brahmasthan.
    canvas.drawCircle(
      center,
      radius * 0.22,
      Paint()..color = AppColors.background,
    );
    canvas.drawCircle(
      center,
      radius * 0.22,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.primary.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant CompassWheelPainter oldDelegate) =>
      oldDelegate.heading != heading || oldDelegate.activeZone != activeZone;
}
