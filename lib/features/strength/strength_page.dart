import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme/app_colors.dart';
import '../astrology/presentation/providers/astrology_provider.dart';
import '../astrology/presentation/utils/astrology_localization.dart';
import '../dosha/domain/entities/zodiac_signs.dart';
import '../kundali/presentation/widgets/rashi_chart/chart_palette.dart';
import '../membership/domain/membership.dart';
import '../membership/presentation/providers/membership_provider.dart';
import '../membership/presentation/widgets/premium_gate.dart';
import 'ashtakavarga.dart';
import 'planet_strength.dart';

/// Ashtakavarga (Sarva and Bhinna) and Shadbala-based planet strength
/// for the active profile. Premium.
class StrengthPage extends ConsumerWidget {
  const StrengthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final premium = ref.watch(canUseProvider(PremiumFeature.strength));
    final kundali = ref.watch(kundaliProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.strengthTitle),
          bottom: premium
              ? TabBar(
                  tabs: [
                    Tab(text: l10n.strengthTab('ashtakavarga')),
                    Tab(text: l10n.strengthTab('shadbala')),
                  ],
                )
              : null,
        ),
        body: !premium
            ? const PremiumLockedBody(feature: PremiumFeature.strength)
            : kundali.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    Center(child: Text(l10n.unableToCalculateKundali)),
                data: (k) {
                  if (k == null) {
                    return Center(child: Text(l10n.unableToCalculateKundali));
                  }
                  try {
                    final av = calculateAshtakavarga(k);
                    final strength = calculatePlanetStrength(k);
                    return TabBarView(
                      children: [
                        _AshtakavargaView(av: av),
                        _StrengthView(strength: strength),
                      ],
                    );
                  } catch (_) {
                    return Center(child: Text(l10n.unableToCalculateKundali));
                  }
                },
              ),
      ),
    );
  }
}

class _AshtakavargaView extends StatefulWidget {
  final Ashtakavarga av;

  const _AshtakavargaView({required this.av});

  @override
  State<_AshtakavargaView> createState() => _AshtakavargaViewState();
}

class _AshtakavargaViewState extends State<_AshtakavargaView> {
  String _planet = 'Sun';

  Color _savColor(int points) => points >= 30
      ? AppColors.success
      : points >= 25
      ? AppColors.textPrimary
      : AppColors.warning;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final av = widget.av;
    final bav = av.bhinna[_planet]!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(l10n.savTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(l10n.savIntro, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.05,
          children: [
            for (var h = 1; h <= 12; h++)
              Container(
                key: ValueKey('sav-house-$h'),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: h == 1 ? AppColors.primary : AppColors.outline,
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.savHouse(h), style: theme.textTheme.labelSmall),
                    Text(
                      '${av.houseSarva(h)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: _savColor(av.houseSarva(h)),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.rashiName(zodiacSigns[(av.lagnaSign + h - 1) % 12]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(l10n.bavTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in ashtakavargaPlanets)
              ChoiceChip(
                label: Text(l10n.planetName(p)),
                selected: p == _planet,
                showCheckmark: false,
                onSelected: (_) => setState(() => _planet = p),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          l10n.bavTotal(bav.fold<int>(0, (a, b) => a + b)),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.6,
          children: [
            for (var h = 1; h <= 12; h++)
              _bavCell(context, h, bav[(av.lagnaSign + h - 1) % 12]),
          ],
        ),
      ],
    );
  }

  Widget _bavCell(BuildContext context, int h, int points) => Container(
    decoration: BoxDecoration(
      color: planetColor(_planet).withValues(alpha: 0.06 + points * 0.05),
      borderRadius: BorderRadius.circular(10),
    ),
    alignment: Alignment.center,
    child: Text(
      '${context.l10n.savHouse(h)}  $points',
      style: Theme.of(context).textTheme.labelLarge,
    ),
  );
}

class _StrengthView extends StatelessWidget {
  final List<PlanetStrength> strength;

  const _StrengthView({required this.strength});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final max = strength.first.total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(l10n.strengthNote, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        for (final s in strength)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              key: ValueKey('strength-${s.planet}'),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: planetColor(s.planet).withValues(alpha: 0.18),
                child: Text(
                  l10n.planetShort(s.planet),
                  style: TextStyle(
                    color: planetColor(s.planet),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              title: Text(l10n.planetName(s.planet)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(
                  value: max <= 0 ? 0 : s.total / max,
                  color: planetColor(s.planet),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              trailing: Text(
                l10n.strengthRupas(s.rupas.toStringAsFixed(2)),
                style: theme.textTheme.labelLarge,
              ),
              children: [
                for (final (key, value) in [
                  ('uchcha', s.uchcha),
                  ('dignity', s.dignity),
                  ('dig', s.dig),
                  ('naisargika', s.naisargika),
                  ('paksha', s.paksha),
                  ('chesta', s.chesta),
                ])
                  ListTile(
                    dense: true,
                    title: Text(l10n.strengthComponent(key)),
                    trailing: Text(value.toStringAsFixed(1)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
