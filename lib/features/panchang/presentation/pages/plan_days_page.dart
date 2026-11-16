import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../daily_loop/domain/personal_muhurat.dart';
import '../../../daily_loop/presentation/daily_loop_providers.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../../membership/domain/membership.dart';
import '../../../membership/presentation/widgets/premium_gate.dart';
import '../../../your_day/domain/day_strength.dart';
import '../../domain/entities/day_divisions.dart';
import '../providers/panchang_location_provider.dart';
import '../providers/plan_days_provider.dart';

/// Premium page: the next seven days in the view the Panchang card showed.
/// "For you" lists the best windows for the chosen purpose; "Today" lists
/// Abhijit Muhurat, Rahu Kaal and the good Choghadiya for each day.
class PlanDaysPage extends StatelessWidget {
  const PlanDaysPage({super.key, required this.forYou});

  final bool forYou;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.planNext7Days)),
      body: PremiumGate(
        feature: PremiumFeature.dayPlanner,
        child: forYou ? const _PersonalView() : const _TodayView(),
      ),
    );
  }
}

class _PersonalView extends ConsumerWidget {
  const _PersonalView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final purpose = ref.watch(muhuratPurposeProvider);
    final week = ref.watch(personalPlanProvider((days: 7, purpose: purpose)));
    final zone = _zone(ref);

    return _Scroll(
      header: [
        Text(
          l10n.muhuratPurposeLabel,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in MuhuratPurpose.values)
              ChoiceChip(
                label: Text(l10n.muhuratPurpose(p.name)),
                selected: p == purpose,
                onSelected: (_) =>
                    ref.read(muhuratPurposeProvider.notifier).select(p),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      body: week.when(
        loading: () => const _Loading(),
        error: (_, _) => _Message(l10n.planLoadError),
        data: (days) {
          if (days.isEmpty) {
            return _Message(l10n.planNeedBirth);
          }
          return Column(
            children: [
              for (final (i, day) in days.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                _DayCard(
                  date: day.date,
                  isToday: i == 0,
                  children: day.windows.isEmpty
                      ? [
                          Text(
                            l10n.muhuratForYouNone,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ]
                      : [
                          for (final (j, w) in day.windows.indexed)
                            _TimeRow(
                              label: '',
                              range: _range(context, zone, w.start, w.end),
                              detail: l10n.muhuratForYouWindow(
                                l10n.choghadiyaName(w.choghadiya.name),
                                l10n.planetName(w.hora),
                                l10n.yourDayTaraName(w.tara.name),
                              ),
                              color: j == 0 ? AppColors.success : AppColors.primary,
                              best: j == 0,
                              weak: w.tara.strength == Strength.bad,
                            ),
                        ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TodayView extends ConsumerWidget {
  const _TodayView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final week = ref.watch(todayPlanProvider(7));
    final zone = _zone(ref);

    return _Scroll(
      header: const [],
      body: week.when(
        loading: () => const _Loading(),
        error: (_, _) => _Message(l10n.planLoadError),
        data: (days) {
          if (days.isEmpty) {
            return _Message(l10n.planNeedLocation);
          }
          return Column(
            children: [
              for (final (i, day) in days.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                _DayCard(
                  date: day.date,
                  isToday: i == 0,
                  children: [
                    if (day.abhijit case final s?)
                      _TimeRow(
                        label: l10n.abhijitMuhurat,
                        detail: null,
                        range: _range(context, zone, s.start, s.end),
                        color: AppColors.success,
                      ),
                    if (day.rahuKaal case final s?)
                      _TimeRow(
                        label: l10n.rahuKaalTitle,
                        detail: null,
                        range: _range(context, zone, s.start, s.end),
                        color: AppColors.error,
                      ),
                    for (final g in day.good)
                      _TimeRow(
                        label: l10n.choghadiyaName(g.kind.name),
                        detail: l10n.choghadiyaQuality(ChoghadiyaQuality.good.name),
                        range: _range(context, zone, g.span.start, g.span.end),
                        color: AppColors.primary,
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The place's time zone, falling back to the device's when no place is set.
tz.Location _zone(WidgetRef ref) {
  final place = ref.watch(panchangPlaceProvider).value;
  return tz.getLocation(place?.location.timezone ?? 'UTC');
}

String _range(BuildContext context, tz.Location zone, DateTime start, DateTime end) {
  final materials = MaterialLocalizations.of(context);
  String time(DateTime utc) => materials.formatTimeOfDay(
    TimeOfDay.fromDateTime(tz.TZDateTime.from(utc, zone)),
  );
  return '${time(start)} – ${time(end)}';
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.header, this.body});

  final List<Widget> header;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ...header,
        ?body,
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.date, required this.isToday, required this.children});

  final DateTime date;
  final bool isToday;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isToday ? 0.8 : 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.MMMEd(locale).format(date),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.planTodayTag,
                    style: TextStyle(
                      color: AppColors.background,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.range,
    this.detail,
    required this.color,
    this.best = false,
    this.weak = false,
  });

  /// The name of the slot, e.g. "Abhijit Muhurat" or "Amrit".
  final String label;
  final String range;
  final String? detail;
  final Color color;
  final bool best;
  final bool weak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: best
                ? Icon(Icons.star_rounded, size: 16, color: color)
                : Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  range,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  [label, ?detail].where((s) => s.isNotEmpty).join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: weak ? AppColors.error : AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
