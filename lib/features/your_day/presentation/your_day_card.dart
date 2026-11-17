import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock_provider.dart';
import '../../astrology/presentation/utils/astrology_localization.dart';
import '../../dosha/domain/entities/zodiac_signs.dart';
import '../../panchang/presentation/utils/panchang_localization.dart';
import '../domain/day_strength.dart';
import 'your_day_provider.dart';

/// "Your day": Tara Bala and Chandra Bala for the active profile, from the
/// Moon right now. Renders nothing until the first result arrives.
class YourDayCard extends ConsumerStatefulWidget {
  /// Sidereal longitude of the natal Moon.
  final double natalMoonLongitude;

  const YourDayCard({super.key, required this.natalMoonLongitude});

  @override
  ConsumerState<YourDayCard> createState() => _YourDayCardState();
}

class _YourDayCardState extends ConsumerState<YourDayCard> {
  /// Last result, shown while the next ten-minute slot is calculated.
  MoonNow? _last;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(appClockProvider);
    final moon = ref.watch(moonNowProvider(moonKey(now))).value ?? _last;
    if (moon == null) return const SizedBox.shrink();
    _last = moon;

    final strength = DayStrength.fromLongitudes(
      natalMoon: widget.natalMoonLongitude,
      transitMoon: moon.longitude,
    );
    return _YourDayView(strength: strength, moon: moon, now: now);
  }
}

class _YourDayView extends StatelessWidget {
  final DayStrength strength;
  final MoonNow moon;
  final DateTime now;

  const _YourDayView({
    required this.strength,
    required this.moon,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final verdict = strength.verdict;
    final tara = strength.tara;
    final nakshatra = localizedNakshatra(
      l10n,
      nakshatraNames[strength.transitNakshatra],
    );
    final moonSign = l10n.rashiName(zodiacSigns[strength.natalMoonSign]);

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: _verdictColor(verdict), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.yourDayTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(_verdictIcon(verdict), color: _verdictColor(verdict)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.yourDayVerdict(verdict.name),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.yourDayVerdictHint(verdict.name),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            _StrengthRow(
              title: l10n.yourDayTaraTitle,
              detail: l10n.yourDayTaraLine(
                l10n.yourDayTaraName(tara.name),
                nakshatra,
              ),
              until: _until(context, moon.nakshatraEndsUtc),
              strength: tara.strength,
            ),
            const SizedBox(height: 10),
            _StrengthRow(
              title: l10n.yourDayChandraTitle,
              detail: strength.isChandrashtama
                  ? l10n.yourDayChandrashtama
                  : l10n.yourDayChandraLine(
                      strength.chandraHouse.toString(),
                      moonSign,
                    ),
              until: _until(context, moon.signEndsUtc),
              strength: strength.chandraBala,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => context.push('/muhurat'),
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text(l10n.yourDayTimings),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _until(BuildContext context, DateTime utc) {
    final material = MaterialLocalizations.of(context);
    final local = utc.toLocal();
    final today = now.toLocal();
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    final sameDay =
        local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
    return context.l10n.yourDayUntil(
      sameDay ? time : '${material.formatShortMonthDay(local)}, $time',
    );
  }
}

class _StrengthRow extends StatelessWidget {
  final String title;
  final String detail;
  final String until;
  final Strength strength;

  const _StrengthRow({
    required this.title,
    required this.detail,
    required this.until,
    required this.strength,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _strengthColor(strength);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(detail, style: theme.textTheme.bodyMedium),
              Text(until, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Text(
            context.l10n.yourDayStrength(strength.name),
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

Color _strengthColor(Strength s) => switch (s) {
  Strength.good => AppColors.success,
  Strength.weak => AppColors.accent,
  Strength.bad => AppColors.error,
};

Color _verdictColor(DayVerdict v) => switch (v) {
  DayVerdict.good => AppColors.success,
  DayVerdict.mixed => AppColors.primary,
  DayVerdict.caution => AppColors.error,
};

IconData _verdictIcon(DayVerdict v) => switch (v) {
  DayVerdict.good => Icons.wb_sunny_rounded,
  DayVerdict.mixed => Icons.contrast_rounded,
  DayVerdict.caution => Icons.shield_moon_outlined,
};
