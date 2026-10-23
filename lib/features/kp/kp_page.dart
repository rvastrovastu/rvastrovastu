import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../astrology/presentation/utils/astrology_localization.dart';
import '../dosha/domain/entities/zodiac_signs.dart';
import '../kundali/presentation/widgets/rashi_chart/chart_palette.dart';
import '../membership/domain/membership.dart';
import '../membership/presentation/providers/membership_provider.dart';
import '../membership/presentation/widgets/premium_gate.dart';
import 'kp.dart';
import 'kp_providers.dart';

/// KP birth chart (cusps, star and sub lords, ruling planets) and KP
/// Prashna (horary) for this moment. Premium.
class KpPage extends ConsumerWidget {
  const KpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final premium = ref.watch(canUseProvider(PremiumFeature.kp));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.kpTitle),
          bottom: premium
              ? TabBar(
                  tabs: [
                    Tab(text: l10n.kpTab('birth')),
                    Tab(text: l10n.kpTab('prashna')),
                  ],
                )
              : null,
        ),
        body: premium
            ? const TabBarView(children: [_BirthTab(), _PrashnaTab()])
            : const PremiumLockedBody(feature: PremiumFeature.kp),
      ),
    );
  }
}

class _BirthTab extends ConsumerWidget {
  const _BirthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref
        .watch(natalKpProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l10n.unableToCalculateKundali)),
          data: (chart) => chart == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.kpNeedProfile,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    ..._chartSections(context, chart),
                    const SizedBox(height: 16),
                    Text(
                      l10n.kpNote,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
        );
  }
}

class _PrashnaTab extends ConsumerStatefulWidget {
  const _PrashnaTab();

  @override
  ConsumerState<_PrashnaTab> createState() => _PrashnaTabState();
}

class _PrashnaTabState extends ConsumerState<_PrashnaTab> {
  KpQuestion _question = KpQuestion.marriage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final prashna = ref.watch(prashnaProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(l10n.kpPrashnaIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        DropdownButtonFormField<KpQuestion>(
          key: const ValueKey('kpQuestion'),
          initialValue: _question,
          decoration: InputDecoration(labelText: l10n.kpQuestionLabel),
          items: [
            for (final q in KpQuestion.values)
              DropdownMenuItem(value: q, child: Text(l10n.kpQuestion(q.name))),
          ],
          onChanged: (q) => setState(() => _question = q ?? _question),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('kpCast'),
          onPressed: prashna.isLoading
              ? null
              : () => ref.read(prashnaProvider.notifier).cast(),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(l10n.kpCast),
        ),
        const SizedBox(height: 16),
        ...prashna.when(
          loading: () => const [Center(child: CircularProgressIndicator())],
          error: (_, _) => [Text(l10n.kpNoPlace)],
          data: (chart) => chart == null
              ? const <Widget>[]
              : [
                  Text(
                    l10n.kpCastAt(
                      DateFormat.yMMMd(
                        l10n.localeName,
                      ).add_jm().format(chart.local),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _VerdictCard(verdict: chart.judge(_question), question: _question),
                  const SizedBox(height: 16),
                  ..._chartSections(context, chart),
                ],
        ),
        const SizedBox(height: 16),
        Text(l10n.kpNote, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _VerdictCard extends StatelessWidget {
  final KpVerdict verdict;
  final KpQuestion question;

  const _VerdictCard({required this.verdict, required this.question});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = verdict.promising ? AppColors.success : AppColors.warning;
    return Card(
      key: const ValueKey('kpVerdict'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  verdict.promising
                      ? Icons.check_circle_rounded
                      : Icons.hourglass_bottom_rounded,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.kpVerdict(
                      verdict.promising ? 'promising' : 'notPromised',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.kpVerdictLine(
                question.cusp,
                l10n.planetName(verdict.subLord),
                verdict.signified.join(', '),
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String _position(AppLocalizations l10n, double lon) {
  final deg = lon % 30;
  final minutes = ((deg - deg.floor()) * 60).floor();
  return '${l10n.rashiName(zodiacSigns[(lon ~/ 30) % 12])} '
      '${deg.floor()}°${minutes.toString().padLeft(2, '0')}′';
}

List<Widget> _chartSections(BuildContext context, KpChart chart) {
  final l10n = context.l10n;
  final theme = Theme.of(context);
  return [
    Text(l10n.kpRuling, style: theme.textTheme.titleMedium),
    const SizedBox(height: 8),
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (role, planet) in chart.rulingPlanets)
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: CircleAvatar(
              backgroundColor: planetColor(planet).withValues(alpha: 0.2),
              child: Text(
                l10n.planetShort(planet),
                style: TextStyle(fontSize: 10, color: planetColor(planet)),
              ),
            ),
            label: Text('${l10n.kpRulingRole(role)}: ${l10n.planetName(planet)}'),
          ),
      ],
    ),
    const SizedBox(height: 20),
    Text(l10n.kpCusps, style: theme.textTheme.titleMedium),
    const SizedBox(height: 8),
    _LordsTable(
      rows: [
        for (var i = 0; i < 12; i++) ('${i + 1}', chart.cusps[i]),
      ],
    ),
    const SizedBox(height: 20),
    Text(l10n.kpPlanets, style: theme.textTheme.titleMedium),
    const SizedBox(height: 8),
    _LordsTable(
      rows: [
        for (final MapEntry(key: planet, value: lon) in chart.planets.entries)
          ('${l10n.planetShort(planet)} · ${chart.houseOf(lon)}', lon),
      ],
    ),
  ];
}

class _LordsTable extends StatelessWidget {
  final List<(String label, double longitude)> rows;

  const _LordsTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final head = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textMuted,
    );
    final cell = theme.textTheme.bodySmall;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.1),
        1: FlexColumnWidth(2.4),
        2: FlexColumnWidth(0.8),
        3: FlexColumnWidth(0.8),
        4: FlexColumnWidth(0.8),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            for (final key in ['house', 'position', 'sign', 'star', 'sub'])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(l10n.kpColumn(key), style: head),
              ),
          ],
        ),
        for (final (label, lon) in rows) _row(context, label, lon, cell),
      ],
    );
  }

  TableRow _row(BuildContext context, String label, double lon, TextStyle? cell) {
    final l10n = context.l10n;
    final lords = kpLords(lon);
    Widget lord(String planet) => Text(
      l10n.planetShort(planet),
      style: cell?.copyWith(
        color: planetColor(planet),
        fontWeight: FontWeight.w700,
      ),
    );
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(label, style: cell),
        ),
        Text(_position(l10n, lon), style: cell),
        lord(lords.sign),
        lord(lords.star),
        lord(lords.sub),
      ],
    );
  }
}
