import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../astrology/domain/entities/kundali.dart';
import '../../../dasha/domain/entities/dasha_period.dart';
import '../../../horoscope/presentation/utils/horoscope_localization.dart'
    hide localizedNakshatra;
import '../../../panchang/presentation/utils/panchang_localization.dart';

/// "Today's Cosmic Snapshot": the three anchors of the chart (Moon sign,
/// birth star, Lagna) as tiles, then the running dasha with how far
/// through it you are.
class CosmicSnapshot extends StatelessWidget {
  const CosmicSnapshot({
    super.key,
    required this.kundali,
    required this.mahadasha,
    required this.antardasha,
  });

  final Kundali kundali;
  final DashaPeriod? mahadasha;
  final DashaPeriod? antardasha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF232861), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.16),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeCosmicSnapshot,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.homeCosmicSnapshotSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Tile(
                    icon: Icons.nightlight_round,
                    label: l10n.homeRashi,
                    value: _localizedRashi(l10n, kundali.moonSign),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Tile(
                    icon: Icons.star_rounded,
                    label: l10n.homeNakshatra,
                    value: localizedNakshatra(l10n, kundali.nakshatra),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Tile(
                    icon: Icons.explore_rounded,
                    label: l10n.homeLagna,
                    value: _localizedRashi(l10n, kundali.ascendant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DashaPanel(mahadasha: mahadasha, antardasha: antardasha),
        ],
      ),
    );
  }

  static String _localizedRashi(AppLocalizations l10n, String rashi) {
    final value = rashi.trim();
    if (value.isEmpty) return value;
    return l10n.rashiName(value[0].toUpperCase() + value.substring(1));
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Tile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryLight,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashaPanel extends StatelessWidget {
  final DashaPeriod? mahadasha;
  final DashaPeriod? antardasha;

  const _DashaPanel({required this.mahadasha, required this.antardasha});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final maha = mahadasha;
    final antar = antardasha;

    String until(DateTime date) =>
        l10n.yourDayUntil(DateFormat.yMMM(l10n.localeName).format(date));

    double progress(DashaPeriod p) {
      final total = p.duration.inMinutes;
      if (total <= 0) return 0;
      final done = DateTime.now().difference(p.startDate).inMinutes;
      return (done / total).clamp(0.0, 1.0);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timelapse_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.homeCurrentDasha,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (maha == null)
            Text(
              l10n.homeCalculatingPlanetaryPeriod,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            _PeriodRow(
              role: l10n.remediesPeriodRole('mahadasha'),
              planet: localizedPlanet(l10n, maha.planet.name),
              until: until(maha.endDate),
              progress: progress(maha),
              strong: true,
            ),
            if (antar != null) ...[
              const SizedBox(height: 12),
              _PeriodRow(
                role: l10n.remediesPeriodRole('antardasha'),
                planet: localizedPlanet(l10n, antar.planet.name),
                until: until(antar.endDate),
                progress: progress(antar),
                strong: false,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final String role;
  final String planet;
  final String until;
  final double progress;
  final bool strong;

  const _PeriodRow({
    required this.role,
    required this.planet,
    required this.until,
    required this.progress,
    required this.strong,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = strong ? AppColors.primary : AppColors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: planet,
                      style: (strong
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleSmall)
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(
                      text: '  $role',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              until,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: strong ? 6 : 4,
            backgroundColor: AppColors.outline,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
