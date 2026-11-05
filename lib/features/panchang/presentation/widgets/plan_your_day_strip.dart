import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/app_clock_provider.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../domain/entities/daily_panchang_input.dart';
import '../../domain/entities/day_divisions.dart';
import '../providers/daily_panchang_provider.dart';
import '../providers/day_divisions_provider.dart';
import '../providers/panchang_location_provider.dart';

/// "Plan your day with Panchang": today's Abhijit Muhurat and Rahu Kaal,
/// and the Choghadiya and Hora running now at your location, each with
/// when it ends. Tapping opens the Muhurat planner with the full day.
/// Shows nothing until the timings are ready.
///
/// With a [personal] view (the user's own best hours), the card has two
/// tabs, "For you" first.
class PlanYourDayStrip extends ConsumerWidget {
  final Widget? personal;

  const PlanYourDayStrip({super.key, this.personal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(panchangPlaceProvider).value;
    if (place == null) return const SizedBox.shrink();

    final now = ref.watch(appClockProvider);
    final location = place.location;
    final zone = tz.getLocation(location.timezone);
    final localNow = tz.TZDateTime.from(now.toUtc(), zone);
    final input = DailyPanchangInput(
      date: DateTime(localNow.year, localNow.month, localNow.day),
      latitude: location.latitude,
      longitude: location.longitude,
      timezone: location.timezone,
    );

    final running = ref.watch(dayDivisionsProvider(input)).value?.at(now);
    if (running == null) return const SizedBox.shrink();
    final day = running.day;
    final panchang = ref.watch(dailyPanchangProvider(input)).value;

    String time(DateTime utc) => MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(tz.TZDateTime.from(utc, zone)));
    String range(TimedPeriod<void> p) => '${time(p.start)} – ${time(p.end)}';

    (TimedPeriod<T>, TimedPeriod<T>?)? currentAndNext<T>(
      List<TimedPeriod<T>> slots,
    ) {
      final i = slots.indexWhere((slot) => slot.contains(now));
      if (i < 0) return null;
      return (slots[i], i + 1 < slots.length ? slots[i + 1] : null);
    }

    final choghadiya = currentAndNext([
      ...day.dayChoghadiya,
      ...day.nightChoghadiya,
    ]);
    final hora = currentAndNext([...day.dayHoras, ...day.nightHoras]);
    final l10n = context.l10n;

    // The Panchang's own strings where available, so the strip matches
    // the planner exactly; otherwise the same periods worked out here.
    final muhuratText = panchang?.muhurat ?? range(day.abhijit);
    final rahuText = panchang?.rahuKaal ?? range(day.rahuKaal);

    return _StripView(
      personal: personal,
      tiles: [
        _Tile(
          icon: Icons.auto_awesome_rounded,
          label: l10n.abhijitMuhurat,
          value: muhuratText,
          color: AppColors.success,
          now: day.abhijit.contains(now),
        ),
        _Tile(
          icon: Icons.warning_amber_rounded,
          label: l10n.rahuKaalTitle,
          value: rahuText,
          color: AppColors.error,
          now: day.rahuKaal.contains(now),
        ),
        if (choghadiya case (final current, final next))
          _Tile(
            icon: Icons.hourglass_top_rounded,
            label: l10n.choghadiyaTitle,
            value:
                '${l10n.choghadiyaName(current.value.name)} · '
                '${l10n.choghadiyaQuality(current.value.quality.name)}',
            detail: [
              l10n.yourDayUntil(time(current.end)),
              if (next != null)
                l10n.choghadiyaNext(
                  l10n.choghadiyaName(next.value.name),
                  time(next.start),
                ),
            ].join('\n'),
            color: _qualityColor(current.value.quality),
          ),
        if (hora case (final current, final next))
          _Tile(
            icon: Icons.public_rounded,
            label: l10n.horaLabel,
            value: l10n.planetName(current.value),
            detail: [
              l10n.yourDayUntil(time(current.end)),
              if (next != null)
                l10n.choghadiyaNext(
                  l10n.planetName(next.value),
                  time(next.start),
                ),
            ].join('\n'),
            color: AppColors.accent,
          ),
      ],
    );
  }
}

class _Tile {
  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final Color color;
  final bool now;

  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.detail,
    this.now = false,
  });
}

class _StripView extends StatefulWidget {
  final List<_Tile> tiles;
  final Widget? personal;

  const _StripView({required this.tiles, this.personal});

  @override
  State<_StripView> createState() => _StripViewState();
}

class _StripViewState extends State<_StripView> {
  /// 0 = For you, 1 = Today; only used with a personal view.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final personal = widget.personal;
    final showPersonal = personal != null && _tab == 0;

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surfaceLight, AppColors.surface],
          ),
        ),
        child: InkWell(
          onTap: () => context.push('/muhurat'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.planYourDayWithPanchang,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                if (personal != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final (i, label) in [
                        l10n.timingsForYou,
                        l10n.timingsToday,
                      ].indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(label),
                          selected: _tab == i,
                          onSelected: (_) => setState(() => _tab = i),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                if (showPersonal)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: personal,
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 8.0;
                      final width = (constraints.maxWidth - gap) / 2;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final tile in widget.tiles)
                            SizedBox(
                              width: width,
                              child: _TileView(tile: tile),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileView extends StatelessWidget {
  final _Tile tile;

  const _TileView({required this.tile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = tile.detail;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: tile.color.withValues(alpha: tile.now ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tile.color.withValues(alpha: tile.now ? 0.8 : 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tile.icon, size: 15, color: tile.color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  tile.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (tile.now)
                Text(
                  context.l10n.dayDivisionNow,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tile.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tile.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Color _qualityColor(ChoghadiyaQuality quality) => switch (quality) {
  ChoghadiyaQuality.good => AppColors.success,
  ChoghadiyaQuality.neutral => AppColors.accent,
  ChoghadiyaQuality.bad => AppColors.error,
};
