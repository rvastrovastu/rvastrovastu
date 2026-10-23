import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../your_day/domain/day_strength.dart';
import '../../domain/entities/daily_horoscope.dart';
import '../utils/horoscope_localization.dart';

/// Today's horoscope: one headline from Tara Bala (or Chandrashtama), then
/// a one-line reading with a rating for career, money and relationships,
/// from where the Moon is today against your birth Moon.
class DailyHoroscopeSection extends StatelessWidget {
  const DailyHoroscopeSection({
    super.key,
    required this.horoscopeAsync,
    this.onRetry,
  });

  final AsyncValue<DailyHoroscope?> horoscopeAsync;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.homeDailyHoroscope,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.horoscopeSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        horoscopeAsync.when(
          loading: () => const _Panel(
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
          error: (error, stack) => _ErrorPanel(onRetry: onRetry),
          data: (horoscope) => horoscope == null
              ? _Panel(child: Text(l10n.homeDailyHoroscopeSubtitle))
              : _ReadingCard(horoscope: horoscope),
        ),
        // The full horoscope (weekly, monthly, by area) lives on its own
        // page.
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () => GoRouter.maybeOf(context)?.push('/rashifal'),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(l10n.rashifalTitle),
          ),
        ),
      ],
    );
  }
}

class _ReadingCard extends StatelessWidget {
  final DailyHoroscope horoscope;

  const _ReadingCard({required this.horoscope});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final strength = horoscope.strength;
    final accent = _verdictColor(horoscope.verdict);

    return _Panel(
      borderColor: accent.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                label: l10n.horoscopeTaraChip(
                  l10n.yourDayTaraName(horoscope.tara.name),
                ),
                color: _strengthColor(horoscope.tara.strength),
              ),
              _Chip(
                label: l10n.horoscopeChandraChip('${horoscope.chandraHouse}'),
                color: _strengthColor(strength.chandraBala),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.horoscopeHeadline(horoscope.headlineKey),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryLight,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.outline),
          for (final reading in horoscope.areas)
            _AreaRow(
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
              line: switch (reading.area) {
                HoroscopeArea.career => l10n.horoscopeCareerLine(
                  'h${reading.chandraHouse}',
                ),
                HoroscopeArea.money => l10n.horoscopeMoneyLine(
                  'h${reading.chandraHouse}',
                ),
                HoroscopeArea.love => l10n.horoscopeLoveLine(
                  'h${reading.chandraHouse}',
                ),
              },
              outlook: reading.outlook,
            ),
          if (horoscope.mahadasha != 'Unknown') ...[
            const Divider(height: 1, color: AppColors.outline),
            const SizedBox(height: 10),
            Row(
            children: [
              const Icon(
                Icons.timelapse_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.horoscopeDashaChip(
                    localizedPlanet(l10n, horoscope.mahadasha),
                    localizedPlanet(l10n, horoscope.antardasha),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
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

class _AreaRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String line;
  final Outlook outlook;

  const _AreaRow({
    required this.icon,
    required this.title,
    required this.line,
    required this.outlook,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = _outlookColor(outlook);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: l10n.horoscopeOutlook(outlook.name),
                      color: color,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  line,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
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

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _Panel({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceLight, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor ?? AppColors.outline),
      ),
      child: child,
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final VoidCallback? onRetry;

  const _ErrorPanel({this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.error,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ),
        ],
      ),
    );
  }
}

Color _outlookColor(Outlook outlook) => switch (outlook) {
  Outlook.good => AppColors.success,
  Outlook.steady => AppColors.accent,
  Outlook.careful => AppColors.error,
};

Color _strengthColor(Strength strength) => switch (strength) {
  Strength.good => AppColors.success,
  Strength.weak => AppColors.accent,
  Strength.bad => AppColors.error,
};

Color _verdictColor(DayVerdict verdict) => switch (verdict) {
  DayVerdict.good => AppColors.success,
  DayVerdict.mixed => AppColors.primary,
  DayVerdict.caution => AppColors.error,
};
