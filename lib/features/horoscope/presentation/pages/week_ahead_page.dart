import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../utils/horoscope_localization.dart';
import '../../../membership/domain/membership.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../membership/presentation/widgets/premium_gate.dart';
import '../../domain/entities/daily_horoscope.dart';
import '../providers/week_ahead_provider.dart';

/// Premium page: career, money and relationships for each of the next
/// [days] days, with the day's overall headline and running dasha.
class WeekAheadPage extends StatelessWidget {
  const WeekAheadPage({super.key, this.days = 7});

  final int days;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.planNext7Days)),
      body: PremiumGate(
        feature: PremiumFeature.weekAhead,
        child: _WeekList(days: days),
      ),
    );
  }
}

class _WeekList extends ConsumerWidget {
  const _WeekList({required this.days});

  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(weekAheadProvider(days));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return week.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _Message(
        l10n.weekAheadLoadError,
        style: theme.textTheme.bodyLarge,
      ),
      data: (items) {
        if (items.isEmpty) {
          return _Message(
            l10n.weekAheadNeedBirth,
            style: theme.textTheme.bodyLarge,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _DayCard(item: items[index], isToday: index == 0),
        );
      },
    );
  }
}

/// Free days of history; Premium looks back [PastDaysPage.premiumDays].
const int freePastDays = 7;

/// "Past days": the readings of recent days, newest first, so a day's
/// guidance can be looked back on. Free users see the last week; Premium
/// shows the last 30 days.
class PastDaysPage extends ConsumerWidget {
  const PastDaysPage({super.key});

  static const int premiumDays = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final premium = ref.watch(canUseProvider(PremiumFeature.weekAhead));
    final days = premium ? premiumDays : freePastDays;
    final history = ref.watch(pastDaysProvider(days));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pastDaysTitle)),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            _Message(l10n.weekAheadLoadError, style: theme.textTheme.bodyLarge),
        data: (items) {
          if (items.isEmpty) {
            return _Message(
              l10n.weekAheadNeedBirth,
              style: theme.textTheme.bodyLarge,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == items.length) {
                return premium
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.pastDaysPremiumNote(premiumDays),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          const PremiumUnlockRow(
                            feature: PremiumFeature.weekAhead,
                          ),
                        ],
                      );
              }
              return _DayCard(item: items[index], isToday: false);
            },
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center, style: style),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.item, required this.isToday});

  final DailyHoroscope item;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final showDasha = item.mahadasha != 'Unknown';

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
                  DateFormat.MMMEd(Localizations.localeOf(context).toString()).format(item.date),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isToday) const _TodayTag(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.horoscopeHeadline(item.headlineKey),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryLight,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          for (final reading in item.areas) ...[
            const Divider(height: 1, color: AppColors.outline),
            _AreaBlock(
              icon: switch (reading.area) {
                HoroscopeArea.career => Icons.work_outline_rounded,
                HoroscopeArea.money => Icons.account_balance_wallet_outlined,
                HoroscopeArea.love => Icons.favorite_border_rounded,
              },
              title: switch (reading.area) {
                HoroscopeArea.career => l10n.homeCareer,
                HoroscopeArea.money => l10n.homeFinance,
                HoroscopeArea.love => l10n.homeRelationships,
              },
              outlook: reading.outlook,
              line: switch (reading.area) {
                HoroscopeArea.career => l10n.horoscopeCareerLine('h${reading.chandraHouse}'),
                HoroscopeArea.money => l10n.horoscopeMoneyLine('h${reading.chandraHouse}'),
                HoroscopeArea.love => l10n.horoscopeLoveLine('h${reading.chandraHouse}'),
              },
              advice: _advice(l10n, reading.area, reading.outlook),
            ),
          ],
          if (showDasha) ...[
            const Divider(height: 1, color: AppColors.outline),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.timelapse_rounded, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.horoscopeDashaChip(
                      localizedPlanet(l10n, item.mahadasha),
                      localizedPlanet(l10n, item.antardasha),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AreaBlock extends StatelessWidget {
  const _AreaBlock({
    required this.icon,
    required this.title,
    required this.outlook,
    required this.line,
    required this.advice,
  });

  final IconData icon;
  final String title;
  final Outlook outlook;
  final String line;
  final String advice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = switch (outlook) {
      Outlook.good => AppColors.success,
      Outlook.steady => AppColors.accent,
      Outlook.careful => AppColors.error,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                child: Text(
                  l10n.horoscopeOutlook(outlook.name),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(line, style: theme.textTheme.bodyMedium?.copyWith(height: 1.35)),
          const SizedBox(height: 4),
          Text(
            advice,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayTag extends StatelessWidget {
  const _TodayTag();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
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
    );
  }
}

/// What to do with each area on a day with this outlook.
String _advice(AppLocalizations l10n, HoroscopeArea area, Outlook outlook) =>
    switch ((area, outlook)) {
      (HoroscopeArea.career, Outlook.good) => l10n.adviceCareerGood,
      (HoroscopeArea.career, Outlook.steady) => l10n.adviceCareerSteady,
      (HoroscopeArea.career, Outlook.careful) => l10n.adviceCareerCareful,
      (HoroscopeArea.money, Outlook.good) => l10n.adviceMoneyGood,
      (HoroscopeArea.money, Outlook.steady) => l10n.adviceMoneySteady,
      (HoroscopeArea.money, Outlook.careful) => l10n.adviceMoneyCareful,
      (HoroscopeArea.love, Outlook.good) => l10n.adviceLoveGood,
      (HoroscopeArea.love, Outlook.steady) => l10n.adviceLoveSteady,
      (HoroscopeArea.love, Outlook.careful) => l10n.adviceLoveCareful,
    };
