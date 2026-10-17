import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../astrology/domain/entities/kundali.dart';
import '../../astrology/presentation/providers/astrology_provider.dart';
import '../../astrology/presentation/utils/astrology_localization.dart';
import '../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../dasha/domain/entities/dasha_birth_data.dart';
import '../../dasha/domain/entities/dasha_period.dart';
import '../../dasha/presentation/providers/dasha_provider.dart';
import '../../dosha/domain/entities/kaal_sarp_result.dart';
import '../../dosha/presentation/providers/dosha_provider.dart';
import '../domain/gemstone_recommendation.dart';

class RemediesPage extends ConsumerWidget {
  const RemediesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kundaliAsync = ref.watch(kundaliProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.remediesTitle)),
      body: kundaliAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$error', textAlign: TextAlign.center),
          ),
        ),
        data: (kundali) {
          if (kundali == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => context.go('/birth-profile'),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(l10n.createBirthProfile),
              ),
            );
          }
          return _RemediesView(kundali: kundali);
        },
      ),
    );
  }
}

class _RemediesView extends ConsumerWidget {
  final Kundali kundali;

  const _RemediesView({required this.kundali});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profile = ref.watch(birthProfileProvider);

    List<GemstoneRecommendation> stones;
    try {
      stones = recommendGemstones(kundali.ascendant);
    } on ArgumentError {
      stones = const [];
    }

    final periods = <(String, DashaPeriod)>[];
    if (profile != null) {
      final birthData = DashaBirthData(
        birthDate: profile.dateOfBirth,
        moonLongitude: kundali.moonLongitude,
      );
      final maha = ref.watch(currentDashaProvider(birthData));
      final antar = ref.watch(currentAntardashaProvider(birthData));
      if (maha != null) periods.add(('mahadasha', maha));
      if (antar != null && antar.planet != maha?.planet) {
        periods.add(('antardasha', antar));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(l10n.remediesIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        Text(l10n.remediesGemsTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(l10n.remediesGemsIntro, style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        for (final stone in stones) ...[
          _GemstoneCard(stone: stone),
          const SizedBox(height: 10),
        ],
        Text(l10n.remediesGemAdvice, style: theme.textTheme.bodySmall),
        if (periods.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(l10n.remediesPeriodsTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          for (final (role, period) in periods) ...[
            _PlanetRemedyCard(
              heading:
                  '${l10n.remediesPeriodRole(role)} · '
                  '${l10n.planetName(_display(period.planet.name))}',
              planetKey: period.planet.name.toLowerCase(),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 14),
        Text(l10n.remediesDoshasTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        const _DoshaRemedies(),
        const SizedBox(height: 20),
        Text(
          l10n.remediesDisclaimer,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static String _display(String name) => name.isEmpty
      ? name
      : name[0].toUpperCase() + name.substring(1).toLowerCase();
}

class _GemstoneCard extends StatelessWidget {
  final GemstoneRecommendation stone;

  const _GemstoneCard({required this.stone});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final key = stone.planet.toLowerCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stone.roles.map((r) => l10n.remediesGemRole(r.name)).join(' · '),
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(l10n.remediesGemName(key), style: theme.textTheme.titleLarge),
            Text(
              l10n.planetName(stone.planet),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(l10n.remediesGemWear(key)),
            const SizedBox(height: 4),
            Text(
              l10n.remediesSubstituteLabel(l10n.remediesGemSubstitute(key)),
              style: theme.textTheme.bodySmall,
            ),
            if (stone.needsCaution) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.remediesGemCaution(l10n.planetName(stone.planet)),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanetRemedyCard extends StatelessWidget {
  final String heading;
  final String planetKey;

  const _PlanetRemedyCard({required this.heading, required this.planetKey});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final day = l10n.remediesDay(planetKey);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              l10n.remediesMantra(planetKey),
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.primaryLight,
              ),
            ),
            Text(
              l10n.remediesMantraLatin(planetKey),
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Text(l10n.remediesMantraHow(day), style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Text(
              l10n.remediesCharity(l10n.remediesCharityItems(planetKey), day),
            ),
            const SizedBox(height: 4),
            Text(l10n.remediesDeity(l10n.remediesDeityName(planetKey))),
          ],
        ),
      ),
    );
  }
}

/// Dosha-specific practices, shown only for doshas active in the chart.
class _DoshaRemedies extends ConsumerWidget {
  const _DoshaRemedies();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final report = ref.watch(doshaReportProvider);

    return report.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Text(l10n.doshaUnable),
      data: (data) {
        final lines = <String>[
          if (data != null && data.manglik.isEffectivelyManglik)
            l10n.remediesManglik,
          if (data != null &&
              (data.sadeSati.isActive || data.sadeSati.currentDhaiya != null))
            l10n.remediesSadeSati,
          if (data != null && data.kaalSarp.status != KaalSarpStatus.none)
            l10n.remediesKaalSarp,
        ];

        if (lines.isEmpty) return Text(l10n.remediesNoDoshas);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.spa_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(line)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
