import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/calendar_observance.dart';
import '../providers/festival_calendar_provider.dart';
import '../../guide/presentation/puja_guide_route.dart';
import '../../month/hindu_month_grid.dart';
import '../widgets/observance_tile.dart';

class FestivalCalendarPage extends ConsumerStatefulWidget {
  const FestivalCalendarPage({super.key});

  @override
  ConsumerState<FestivalCalendarPage> createState() =>
      _FestivalCalendarPageState();
}

class _FestivalCalendarPageState extends ConsumerState<FestivalCalendarPage> {
  int _monthOffset = 0;
  ObservanceCategory? _filter;
  bool _grid = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final calendar = ref.watch(festivalCalendarProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.festivalCalendarTitle)),
      body: calendar.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(l10n.festivalCalculating),
            ],
          ),
        ),
        error: (error, _) => _CenteredMessage(
          icon: Icons.error_outline,
          text: '${l10n.festivalUnable}\n$error',
          action: FilledButton(
            onPressed: () => ref.invalidate(festivalCalendarProvider),
            child: Text(l10n.tryAgain),
          ),
        ),
        data: (data) {
          if (data == null) {
            return _CenteredMessage(
              icon: Icons.location_off_outlined,
              text: l10n.festivalLocationNeeded,
              action: FilledButton.icon(
                onPressed: () => context.go('/birth-profile'),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(l10n.createBirthProfile),
              ),
            );
          }
          return _buildCalendar(context, data);
        },
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, FestivalCalendar calendar) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = ref.watch(festivalTodayProvider);

    final month = DateTime(
      calendar.from.year,
      calendar.from.month + _monthOffset,
    );
    final monthLabel = DateFormat.yMMMM(l10n.localeName).format(month);

    final events = calendar
        .inMonth(month.year, month.month)
        .where((o) => _filter == null || o.id.category == _filter)
        .toList();

    final upcomingMajor = calendar.upcoming(today, majorOnly: true);
    final next = upcomingMajor.isEmpty ? null : upcomingMajor.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(
          calendar.place.fallbackCity == null
              ? l10n.festivalForCurrentLocation
              : l10n.festivalForCity(calendar.place.fallbackCity!),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(l10n.festivalTapForGuide, style: theme.textTheme.bodySmall),
        if (next != null) ...[
          const SizedBox(height: 12),
          NextFestivalCard(
            observance: next,
            today: today,
            onTap: () => context.push(pujaGuidePath(next.id, next.date)),
          ),
        ],
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          key: const ValueKey('calendarView'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.view_list_rounded),
              label: Text(l10n.calendarView('list')),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.calendar_view_month_rounded),
              label: Text(l10n.calendarView('month')),
            ),
          ],
          selected: {_grid},
          onSelectionChanged: (s) => setState(() => _grid = s.first),
        ),
        const SizedBox(height: 12),
        if (!_grid)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(context, null, l10n.festivalFilter('all')),
              for (final category in ObservanceCategory.values)
                _filterChip(
                  context,
                  category,
                  l10n.festivalFilter(category.name),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
              onPressed: _monthOffset > 0
                  ? () => setState(() => _monthOffset--)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                monthLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
              onPressed: _monthOffset < 11
                  ? () => setState(() => _monthOffset++)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_grid)
          HinduMonthGrid(
            month: month,
            observances: calendar.inMonth(month.year, month.month),
            today: today,
          )
        else if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              l10n.festivalNone,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (final observance in events)
            ObservanceTile(observance: observance, today: today),
        const SizedBox(height: 20),
        Text(
          l10n.festivalDisclaimer,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _filterChip(
    BuildContext context,
    ObservanceCategory? category,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == category,
        onSelected: (_) => setState(() => _filter = category),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget action;

  const _CenteredMessage({
    required this.icon,
    required this.text,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            action,
          ],
        ),
      ),
    );
  }
}
