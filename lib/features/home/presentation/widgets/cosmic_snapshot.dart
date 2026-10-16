import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../astrology/domain/entities/kundali.dart';
import '../../../dasha/domain/entities/dasha_period.dart';
import '../../../horoscope/presentation/utils/horoscope_localization.dart'
    hide localizedNakshatra;
import '../../../panchang/presentation/utils/panchang_localization.dart';

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
    final colors = theme.colorScheme;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 7),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryContainer, colors.surfaceContainerHighest],
        ),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface.withValues(alpha: 0.7),
                  ),
                  child: Icon(Icons.auto_awesome, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeCosmicSnapshot,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.homeCosmicSnapshotSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final metrics = <Widget>[
                  _metric(
                    context,
                    label: l10n.homeRashi,
                    value: _localizedRashi(l10n, kundali.moonSign),
                    icon: Icons.nightlight_outlined,
                  ),
                  _metric(
                    context,
                    label: l10n.homeNakshatra,
                    value: localizedNakshatra(l10n, kundali.nakshatra),
                    icon: Icons.star_outline_rounded,
                  ),
                  _metric(
                    context,
                    label: l10n.homeLagna,
                    value: _localizedRashi(l10n, kundali.ascendant),
                    icon: Icons.explore_outlined,
                  ),
                ];

                if (constraints.maxWidth < 360) {
                  final itemWidth = (constraints.maxWidth - 12) / 2;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 18,
                    children: [
                      for (final metric in metrics)
                        SizedBox(width: itemWidth, child: metric),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final metric in metrics) Expanded(child: metric),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Divider(color: colors.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              l10n.homeCurrentDasha,
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mahadasha == null
                  ? l10n.homeCalculatingPlanetaryPeriod
                  : localizedPlanet(l10n, _dashaName(mahadasha)),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (antardasha != null) ...[
              const SizedBox(height: 3),
              Text(
                l10n.homeAntardasha(
                  localizedPlanet(l10n, _dashaName(antardasha)),
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _dashaName(DashaPeriod? dasha) {
    return dasha?.planet.name ?? '—';
  }

  String _localizedRashi(AppLocalizations l10n, String rashi) {
    return l10n.rashiName(
      rashi.trim().replaceFirst(rashi.trim()[0], rashi.trim()[0].toUpperCase()),
    );
  }
}
