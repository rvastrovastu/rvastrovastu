import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../../dosha/domain/entities/zodiac_signs.dart';
import '../../domain/entities/transit.dart';
import '../providers/gochar_provider.dart';

class GocharPage extends ConsumerWidget {
  const GocharPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final report = ref.watch(gocharReportProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gocharTitle)),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(gocharReportProvider),
                  child: Text(l10n.tryAgain),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          if (data == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => context.go('/birth-profile'),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(l10n.createBirthProfile),
              ),
            );
          }
          return _GocharView(report: data);
        },
      ),
    );
  }
}

class _GocharView extends StatelessWidget {
  final GocharReport report;

  const _GocharView({required this.report});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = DateFormat.yMMMd(l10n.localeName);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(l10n.gocharIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        for (final reading in report.current) ...[
          _TransitCard(reading: reading, dates: dates),
          const SizedBox(height: 10),
        ],
        if (report.upcoming.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(l10n.gocharUpcoming, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final ingress in report.upcoming)
                  ListTile(
                    leading: _ToneDot(tone: ingress.tone),
                    title: Text(
                      l10n.gocharIngress(
                        l10n.planetName(ingress.planet.displayKey),
                        l10n.rashiName(zodiacSigns[ingress.signIndex]),
                      ),
                    ),
                    subtitle: Text(
                      '${dates.format(ingress.date.toLocal())} · '
                      '${l10n.gocharHouseFromMoon(ingress.houseFromMoon)}',
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          l10n.gocharDisclaimer,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TransitCard extends StatelessWidget {
  final TransitReading reading;
  final DateFormat dates;

  const _TransitCard({required this.reading, required this.dates});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final favourable = reading.tone == TransitTone.favourable;

    final span = <String>[
      if (reading.since != null)
        l10n.gocharSince(dates.format(reading.since!.toLocal())),
      if (reading.until != null && reading.nextSignIndex != null)
        l10n.gocharUntil(
          dates.format(reading.until!.toLocal()),
          l10n.rashiName(zodiacSigns[reading.nextSignIndex!]),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.gocharPlanetIn(
                      l10n.planetName(reading.planet.displayKey),
                      l10n.rashiName(zodiacSigns[reading.signIndex]),
                    ),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: favourable
                        ? AppColors.success.withValues(alpha: 0.16)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.gocharTone(reading.tone.name),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: favourable
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${l10n.gocharHouseFromMoon(reading.houseFromMoon)} — '
              '${l10n.gocharHouseTheme('h${reading.houseFromMoon}')}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              l10n.gocharHouseFromLagna(reading.houseFromLagna),
              style: theme.textTheme.bodySmall,
            ),
            for (final line in span) ...[
              const SizedBox(height: 2),
              Text(line, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToneDot extends StatelessWidget {
  final TransitTone tone;

  const _ToneDot({required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tone == TransitTone.favourable
            ? AppColors.success
            : AppColors.textMuted,
      ),
    );
  }
}
