import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/daily_horoscope.dart';
import '../utils/horoscope_localization.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          l10n.homeDailyHoroscope,
          l10n.homeDailyHoroscopeSubtitle,
        ),
        const SizedBox(height: 12),
        horoscopeAsync.when(
          loading: () => _loadingState(context),
          error: (error, stack) => _errorState(context),
          data: (horoscope) {
            if (horoscope == null) {
              return _fallbackCards(context);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dateContext(context, horoscope),
                const SizedBox(height: 10),
                _horoscopeCard(
                  context,
                  icon: Icons.work_outline_rounded,
                  title: l10n.homeCareer,
                  text: localizedCareer(l10n, horoscope),
                ),
                const SizedBox(height: 8),
                _horoscopeCard(
                  context,
                  icon: Icons.account_balance_wallet_outlined,
                  title: l10n.homeFinance,
                  text: localizedFinance(l10n, horoscope),
                ),
                const SizedBox(height: 8),
                _horoscopeCard(
                  context,
                  icon: Icons.favorite_border_rounded,
                  title: l10n.homeRelationships,
                  text: localizedRelationships(l10n, horoscope),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _dateContext(BuildContext context, DailyHoroscope horoscope) {
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = DateFormat.yMMMMd(locale).format(horoscope.date);
    final dashaLabel =
        '${localizedPlanet(AppLocalizations.of(context), horoscope.mahadasha)}'
        ' · '
        '${localizedPlanet(AppLocalizations.of(context), horoscope.antardasha)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  dateLabel,
                  softWrap: true,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.timelapse_rounded, size: 17, color: colors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  dashaLabel,
                  softWrap: true,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loadingState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.30),
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _errorState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.error,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.homeDailyHoroscopeSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
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

  Widget _fallbackCards(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        _horoscopeCard(
          context,
          icon: Icons.work_outline_rounded,
          title: l10n.homeCareer,
          text: l10n.homeCareerGuidance,
        ),
        const SizedBox(height: 8),
        _horoscopeCard(
          context,
          icon: Icons.account_balance_wallet_outlined,
          title: l10n.homeFinance,
          text: l10n.homeFinanceGuidance,
        ),
        const SizedBox(height: 8),
        _horoscopeCard(
          context,
          icon: Icons.favorite_border_rounded,
          title: l10n.homeRelationships,
          text: l10n.homeRelationshipsGuidance,
        ),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title, String subtitle) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _horoscopeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String text,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: colors.onSurfaceVariant,
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
