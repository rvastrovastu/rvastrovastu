import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/app_clock_provider.dart';
import '../../domain/entities/daily_panchang_input.dart';
import '../../domain/entities/day_divisions.dart';
import '../providers/day_divisions_provider.dart';
import '../providers/panchang_location_provider.dart';

/// A one-line banner with the Choghadiya running now at your location,
/// when it ends and what comes next. Tapping opens the Muhurat planner,
/// which lists the whole day. Shows nothing until the timings are ready.
class ChoghadiyaStrip extends ConsumerWidget {
  const ChoghadiyaStrip({super.key});

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

    final days = ref.watch(dayDivisionsProvider(input)).value;
    final running = days?.at(now);
    if (running == null) return const SizedBox.shrink();

    final slots = [
      ...running.day.dayChoghadiya,
      ...running.day.nightChoghadiya,
    ];
    final index = slots.indexWhere((slot) => slot.contains(now));
    if (index < 0) return const SizedBox.shrink();

    final current = slots[index];
    final next = index + 1 < slots.length ? slots[index + 1] : null;

    String time(DateTime utc) => MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(tz.TZDateTime.from(utc, zone)));

    return _StripView(
      current: current.value,
      until: time(current.end),
      next: next?.value,
      nextAt: next == null ? null : time(next.start),
    );
  }
}

class _StripView extends StatelessWidget {
  final Choghadiya current;
  final String until;
  final Choghadiya? next;
  final String? nextAt;

  const _StripView({
    required this.current,
    required this.until,
    required this.next,
    required this.nextAt,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = _qualityColor(current.quality);
    final upcoming = next;

    return Material(
      color: color.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/muhurat'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Icon(Icons.hourglass_top_rounded, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${l10n.choghadiyaTitle}: ',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          TextSpan(
                            text: l10n.choghadiyaName(current.name),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text:
                                '  ·  ${l10n.choghadiyaQuality(current.quality.name)}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        l10n.yourDayUntil(until),
                        if (upcoming != null && nextAt != null)
                          l10n.choghadiyaNext(
                            l10n.choghadiyaName(upcoming.name),
                            nextAt!,
                          ),
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _qualityColor(ChoghadiyaQuality quality) => switch (quality) {
  ChoghadiyaQuality.good => AppColors.success,
  ChoghadiyaQuality.neutral => AppColors.accent,
  ChoghadiyaQuality.bad => AppColors.error,
};
