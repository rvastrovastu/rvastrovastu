import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/calendar_observance.dart';
import '../../guide/presentation/puja_guide_route.dart';

IconData observanceIcon(ObservanceId id) {
  switch (id.category) {
    case ObservanceCategory.festival:
      return Icons.celebration_outlined;
    case ObservanceCategory.ekadashi:
      return Icons.spa_outlined;
    case ObservanceCategory.fullNewMoon:
      return id == ObservanceId.purnima
          ? Icons.brightness_1_outlined
          : Icons.brightness_2_outlined;
    case ObservanceCategory.vrat:
      return Icons.local_florist_outlined;
  }
}

/// Days from [today] to [date], both date-only.
int daysUntil(DateTime today, DateTime date) =>
    DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;

String relativeDayLabel(AppLocalizations l10n, DateTime today, DateTime date) {
  final days = daysUntil(today, date);
  if (days == 0) return l10n.festivalToday;
  if (days == 1) return l10n.festivalTomorrow;
  return l10n.festivalInDays(days);
}

class ObservanceTile extends StatelessWidget {
  final CalendarObservance observance;
  final DateTime today;

  const ObservanceTile({
    super.key,
    required this.observance,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isMajor = observance.id.isMajorFestival;
    final isPast = observance.date.isBefore(today);
    final days = daysUntil(today, observance.date);

    final weekday = DateFormat.E(l10n.localeName).format(observance.date);
    final subtitle = <String>[
      weekday,
      if (observance.isShukla != null)
        l10n.festivalPaksha(observance.isShukla! ? 'shukla' : 'krishna'),
    ].join(' · ');

    return Opacity(
      opacity: isPast ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: () =>
              context.push(pujaGuidePath(observance.id, observance.date)),
          leading: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isMajor
                  ? colors.primary.withValues(alpha: 0.18)
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${observance.date.day}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isMajor ? colors.primary : null,
                  ),
                ),
                Icon(
                  observanceIcon(observance.id),
                  size: 14,
                  color: isMajor ? colors.primary : colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
          title: Text(
            l10n.festivalName(observance.id.name),
            style: TextStyle(
              fontWeight: isMajor ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: Text(subtitle),
          trailing: days >= 0 && days <= 7
              ? Chip(
                  label: Text(relativeDayLabel(l10n, today, observance.date)),
                  visualDensity: VisualDensity.compact,
                )
              : null,
        ),
      ),
    );
  }
}

/// Highlight card for the next major festival, used on the calendar page
/// and on Home.
class NextFestivalCard extends StatelessWidget {
  final CalendarObservance observance;
  final DateTime today;
  final VoidCallback? onTap;

  const NextFestivalCard({
    super.key,
    required this.observance,
    required this.today,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final date = DateFormat.MMMEd(l10n.localeName).format(observance.date);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: 0.22),
                colors.secondary.withValues(alpha: 0.12),
              ],
            ),
          ),
          child: Row(
            children: [
              Icon(
                observanceIcon(observance.id),
                size: 36,
                color: colors.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.festivalNextUp,
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.festivalName(observance.id.name),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(date, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                relativeDayLabel(l10n, today, observance.date),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
