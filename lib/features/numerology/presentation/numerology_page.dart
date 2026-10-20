import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../membership/domain/membership.dart';
import '../../membership/presentation/providers/membership_provider.dart';
import '../../membership/presentation/widgets/premium_gate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../astrology/presentation/utils/astrology_localization.dart';
import '../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../domain/numerology.dart';

class NumerologyPage extends ConsumerStatefulWidget {
  const NumerologyPage({super.key});

  @override
  ConsumerState<NumerologyPage> createState() => _NumerologyPageState();
}

class _NumerologyPageState extends ConsumerState<NumerologyPage> {
  final _nameController = TextEditingController();
  String? _seededFor;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profile = ref.watch(birthProfileProvider);

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.numerologyTitle)),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => context.go('/birth-profile'),
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(l10n.createBirthProfile),
          ),
        ),
      );
    }

    // Start the name field with the profile name, once per profile.
    if (_seededFor != profile.id) {
      _seededFor = profile.id;
      _nameController.text = profile.name;
    }

    final report = const Numerology()(
      dateOfBirth: profile.dateOfBirth,
      name: _nameController.text,
      year: DateTime.now().year,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.numerologyTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(l10n.numerologyIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _NumberTile(
                  label: l10n.numerologyMulank,
                  hint: l10n.numerologyMulankHint,
                  number: report.mulank,
                  highlighted: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberTile(
                  label: l10n.numerologyBhagyank,
                  hint: l10n.numerologyBhagyankHint,
                  number: report.bhagyank,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _NumberMeaning(number: report.mulank),
          const SizedBox(height: 20),
          if (!ref.watch(canUseProvider(PremiumFeature.nameNumerology)))
            const PremiumLockedCard(feature: PremiumFeature.nameNumerology)
          else ...[
          Text(l10n.numerologyNameTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.numerologyNameLabel,
              helperText: l10n.numerologyNameHelper,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (report.nameNumber == null)
            Text(l10n.numerologyNameNone, style: theme.textTheme.bodySmall)
          else ...[
            _NumberTile(
              label: l10n.numerologyNameNumber,
              hint: l10n.numerologyCompound(report.nameCompound!),
              number: report.nameNumber!,
            ),
            const SizedBox(height: 10),
            Text(
              report.nameNumber == report.mulank ||
                      report.nameNumber == report.bhagyank
                  ? l10n.numerologyNameInHarmony
                  : l10n.numerologyNameDifferent,
              style: theme.textTheme.bodySmall,
            ),
          ],
          ],
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_repeat_outlined),
              title: Text(
                l10n.numerologyPersonalYear(
                  '${report.year}',
                  report.personalYear,
                ),
              ),
              subtitle: Text(
                l10n.numerologyYearTheme('n${report.personalYear}'),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.numerologyDisclaimer,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NumberTile extends StatelessWidget {
  final String label;
  final String hint;
  final int number;
  final bool highlighted;

  const _NumberTile({
    required this.label,
    required this.hint,
    required this.number,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final planet = Numerology.rulingPlanet[number] ?? '';

    return Card(
      color: highlighted ? AppColors.surfaceLight : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              '$number',
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.numerologyRuledBy(l10n.planetName(planet)),
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(hint, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberMeaning extends StatelessWidget {
  final int number;

  const _NumberMeaning({required this.number});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final key = 'n$number';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.numerologyTraits(key),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.numerologyLucky(
                l10n.numerologyLuckyDay(key),
                l10n.numerologyLuckyColour(key),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
