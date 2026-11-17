import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../domain/entities/daily_panchang_input.dart';
import '../../domain/entities/day_divisions.dart';
import '../providers/day_divisions_provider.dart';

/// Yamaganda, Gulika, Choghadiya and Hora for the Vedic day that contains
/// [now], with the running period highlighted.
///
/// The Daily Timing page shows everything but Choghadiya
/// ([withChoghadiya] false); the Muhurat planner shows only Choghadiya
/// ([choghadiyaOnly]), for its chosen date.
class DayDivisionsSection extends ConsumerStatefulWidget {
  /// The local calendar date at the place.
  final DailyPanchangInput today;
  final DateTime now;
  final bool withChoghadiya;
  final bool choghadiyaOnly;

  const DayDivisionsSection({
    super.key,
    required this.today,
    required this.now,
    this.withChoghadiya = true,
    this.choghadiyaOnly = false,
  });

  @override
  ConsumerState<DayDivisionsSection> createState() =>
      _DayDivisionsSectionState();
}

class _DayDivisionsSectionState extends ConsumerState<DayDivisionsSection> {
  /// null follows the clock; otherwise the user's Day/Night choice.
  bool? _showNight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final days = ref.watch(dayDivisionsProvider(widget.today));

    return days.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (days) {
        final running = days.at(widget.now);
        if (running == null) {
          return _note(context, l10n.dayDivisionsUnavailable);
        }
        return _content(
          context,
          running.day,
          beforeSunrise: running.beforeSunrise,
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    DayDivisions d, {
    required bool beforeSunrise,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final location = tz.getLocation(widget.today.timezone);
    final night = _showNight ?? d.isNight(widget.now);

    String time(DateTime utc) {
      final local = tz.TZDateTime.from(utc, location);
      return MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    }

    String range<T>(TimedPeriod<T> p) => '${time(p.start)} – ${time(p.end)}';

    final choghadiya = night ? d.nightChoghadiya : d.dayChoghadiya;
    final horas = night ? d.nightHoras : d.dayHoras;

    final showOthers = !widget.choghadiyaOnly;
    final showChoghadiya = widget.withChoghadiya || widget.choghadiyaOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showOthers) ...[
        _periodCard(
          context,
          icon: Icons.hourglass_bottom_rounded,
          title: l10n.yamagandaTitle,
          value: range(d.yamaganda),
          description: l10n.yamagandaDescription,
          active: d.yamaganda.contains(widget.now),
        ),
        const SizedBox(height: 10),
        _periodCard(
          context,
          icon: Icons.replay_rounded,
          title: l10n.gulikaTitle,
          value: range(d.gulika),
          description: l10n.gulikaDescription,
          active: d.gulika.contains(widget.now),
        ),
        const SizedBox(height: 20),
        ],
        if (showChoghadiya) ...[
        Text(
          l10n.choghadiyaTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(l10n.choghadiyaIntro, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.wb_sunny_outlined),
              label: Text(l10n.dayDivisionDay),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.nights_stay_outlined),
              label: Text(l10n.dayDivisionNight),
            ),
          ],
          selected: {night},
          onSelectionChanged: (s) => setState(() => _showNight = s.first),
        ),
        if (beforeSunrise) ...[
          const SizedBox(height: 8),
          Text(l10n.dayDivisionsBeforeSunrise, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final p in choghadiya)
                  _row(
                    context,
                    leading: _QualityDot(p.value.quality),
                    title: l10n.choghadiyaName(p.value.name),
                    trailing: l10n.choghadiyaQuality(p.value.quality.name),
                    trailingColor: _qualityColor(p.value.quality),
                    time: range(p),
                    active: p.contains(widget.now),
                  ),
              ],
            ),
          ),
        ),
        ],
        if (showOthers) ...[
        const SizedBox(height: 20),
        Text(
          l10n.horaTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(l10n.horaIntro, style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final h in horas)
                  _row(
                    context,
                    leading: const Icon(
                      Icons.public,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    title: l10n.planetName(h.value),
                    time: range(h),
                    active: h.contains(widget.now),
                  ),
              ],
            ),
          ),
        ),
        ],
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required Widget leading,
    required String title,
    required String time,
    required bool active,
    String? trailing,
    Color? trailingColor,
  }) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: active
          ? BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, width: 1),
            )
          : null,
      child: Row(
        children: [
          SizedBox(width: 18, child: Center(child: leading)),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: trailingColor,
                    ),
                  ),
                if (active)
                  Text(
                    l10n.dayDivisionNow,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          Text(time, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _periodCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String description,
    required bool active,
  }) {
    final theme = Theme.of(context);

    return Card(
      shape: active
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.primary),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active ? '$title · ${context.l10n.dayDivisionNow}' : title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(description, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _note(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

Color _qualityColor(ChoghadiyaQuality q) => switch (q) {
  ChoghadiyaQuality.good => AppColors.success,
  ChoghadiyaQuality.neutral => AppColors.accent,
  ChoghadiyaQuality.bad => AppColors.error,
};

class _QualityDot extends StatelessWidget {
  final ChoghadiyaQuality quality;

  const _QualityDot(this.quality);

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: _qualityColor(quality),
      shape: BoxShape.circle,
    ),
  );
}
