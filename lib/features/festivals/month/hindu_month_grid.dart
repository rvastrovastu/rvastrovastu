import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../panchang/presentation/utils/panchang_localization.dart';
import '../domain/entities/calendar_observance.dart';
import '../domain/usecases/build_festival_calendar.dart';
import '../guide/presentation/puja_guide_route.dart';
import '../presentation/providers/festival_calendar_provider.dart';
import 'hindu_month.dart';
import 'hindu_month_provider.dart';

/// A wall-calendar month: each day with its sunrise tithi and festivals,
/// in the Amanta or Purnimanta reckoning.
class HinduMonthGrid extends ConsumerWidget {
  final DateTime month;
  final List<CalendarObservance> observances;
  final DateTime today;

  const HinduMonthGrid({
    super.key,
    required this.month,
    required this.observances,
    required this.today,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final days = ref.watch(hinduMonthProvider(DateTime(month.year, month.month)));
    final purnimanta =
        ref.watch(purnimantaProvider) ?? {'hi', 'pa'}.contains(l10n.localeName);

    return days.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Text(l10n.festivalUnable),
      data: (list) {
        if (list == null || list.isEmpty) {
          return Text(l10n.festivalLocationNeeded);
        }
        return _grid(context, ref, list, purnimanta);
      },
    );
  }

  Widget _grid(
    BuildContext context,
    WidgetRef ref,
    List<HinduDay> days,
    bool purnimanta,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = l10n.localeName;

    LunarMonth? monthOf(HinduDay d) => purnimanta ? d.purnimantaMonth : d.month;
    final names = <String>[];
    for (final d in days) {
      final m = monthOf(d);
      if (m == null) continue;
      final name = d.adhik
          ? l10n.hinduMonthAdhik(l10n.hinduMonthName(m.name))
          : l10n.hinduMonthName(m.name);
      if (names.isEmpty || names.last != name) names.add(name);
    }

    // Monday-first weekday labels.
    final monday = DateTime(2024, 1, 1);
    final weekdays = [
      for (var i = 0; i < 7; i++)
        DateFormat.E(locale).format(DateTime(monday.year, 1, 1 + i)),
    ];
    final lead = days.first.date.weekday - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                names.join(' – '),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(value: false, label: Text(l10n.hinduMonthSystem('amanta'))),
                ButtonSegment(value: true, label: Text(l10n.hinduMonthSystem('purnimanta'))),
              ],
              selected: {purnimanta},
              onSelectionChanged: (s) =>
                  ref.read(purnimantaProvider.notifier).set(s.first),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.72,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (final w in weekdays)
              Center(
                child: Text(w, style: theme.textTheme.labelSmall),
              ),
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (final d in days) _cell(context, d),
          ],
        ),
      ],
    );
  }

  List<CalendarObservance> _on(DateTime date) => [
    for (final o in observances)
      if (o.date.year == date.year &&
          o.date.month == date.month &&
          o.date.day == date.day)
        o,
  ];

  Widget _cell(BuildContext context, HinduDay d) {
    final theme = Theme.of(context);
    final events = _on(d.date);
    final isToday = d.date == today;
    final tithi = d.tithi;
    final special = tithi == 14 || tithi == 29;

    return InkWell(
      key: ValueKey('day-${d.date.day}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showDay(context, d, events),
      child: Container(
        decoration: BoxDecoration(
          color: events.any((e) => e.id.isMajorFestival)
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isToday ? AppColors.primary : AppColors.outline,
            width: isToday ? 1.6 : 0.6,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${d.date.day}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (tithi != null)
              special
                  ? Icon(
                      tithi == 14 ? Icons.circle_outlined : Icons.circle,
                      size: 12,
                      color: AppColors.primaryLight,
                    )
                  : Text(
                      '${d.tithiInPaksha}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: d.isShukla
                            ? AppColors.primaryLight
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: events.isEmpty ? Colors.transparent : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDay(
    BuildContext context,
    HinduDay d,
    List<CalendarObservance> events,
  ) {
    final l10n = context.l10n;
    final place = ProviderScope.containerOf(
      context,
    ).read(festivalPlaceProvider).value;
    String? time(DateTime? utc) {
      if (utc == null || place == null) return null;
      final local = tz.TZDateTime.from(utc, tz.getLocation(place.timezone));
      return MaterialLocalizations.of(context)
          .formatTimeOfDay(TimeOfDay.fromDateTime(local));
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheet) {
        final theme = Theme.of(sheet);
        final month = d.month;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMMEEEEd(l10n.localeName).format(d.date),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                if (d.tithi != null)
                  Text(
                    localizedTithi(l10n, tithiCanonicalName(d.tithi!)),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                if (month != null)
                  Text(
                    '${l10n.hinduMonthSystem('amanta')}: ${l10n.hinduMonthName(month.name)}'
                    ' · ${l10n.hinduMonthSystem('purnimanta')}: '
                    '${l10n.hinduMonthName(d.purnimantaMonth!.name)}',
                    style: theme.textTheme.bodySmall,
                  ),
                if (time(d.sunrise) case final rise?)
                  Text(
                    '${l10n.sunrise} $rise · ${l10n.sunset} ${time(d.sunset) ?? '—'}',
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                for (final e in events)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.celebration_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(l10n.festivalName(e.id.name)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheet).pop();
                      context.push(pujaGuidePath(e.id, e.date));
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
