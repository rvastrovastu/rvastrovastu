import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme/app_colors.dart';
import '../astrology/presentation/utils/astrology_localization.dart';
import '../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../dosha/domain/entities/zodiac_signs.dart';
import '../kundali/presentation/providers/chart_style_provider.dart';
import '../kundali/presentation/widgets/rashi_chart/rashi_chart_v2.dart';
import '../kundali/presentation/widgets/rashi_chart/south_indian_chart.dart';
import '../membership/domain/membership.dart';
import '../membership/presentation/providers/membership_provider.dart';
import '../membership/presentation/widgets/premium_gate.dart';
import 'varshphal.dart';
import 'varshphal_pdf_service.dart';
import 'varshphal_providers.dart';

/// Varshphal: the year ahead from the solar-return chart. The Muntha and
/// its one-line theme are free; the year chart, planet houses and the PDF
/// need Premium or the one-time Varshphal purchase.
class VarshphalPage extends ConsumerStatefulWidget {
  const VarshphalPage({super.key});

  @override
  ConsumerState<VarshphalPage> createState() => _VarshphalPageState();
}

class _VarshphalPageState extends ConsumerState<VarshphalPage> {
  bool _next = false;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = ref.watch(currentVarshaProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.varshphalTitle)),
      body: current == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.varshphalNeedProfile, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go('/birth-profile'),
                      child: Text(l10n.createBirthProfile),
                    ),
                  ],
                ),
              ),
            )
          : _body(context, current + (_next ? 1 : 0)),
    );
  }

  Widget _body(BuildContext context, int completedYears) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final year = ref.watch(varshphalProvider(completedYears));
    final unlocked = ref.watch(canUseProvider(PremiumFeature.varshphal));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SegmentedButton<bool>(
          key: const ValueKey('varshphalYear'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, label: Text(l10n.varshphalYear('current'))),
            ButtonSegment(value: true, label: Text(l10n.varshphalYear('next'))),
          ],
          selected: {_next},
          onSelectionChanged: (s) => setState(() => _next = s.first),
        ),
        const SizedBox(height: 16),
        ...year.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (_, _) => [Text(l10n.unableToCalculateKundali)],
          data: (v) => v == null
              ? [Text(l10n.unableToCalculateKundali)]
              : [
                  _summary(context, v),
                  const SizedBox(height: 16),
                  if (unlocked)
                    ..._details(context, v)
                  else
                    const PremiumLockedCard(feature: PremiumFeature.varshphal),
                  const SizedBox(height: 16),
                  Text(l10n.varshphalNote, style: theme.textTheme.bodySmall),
                ],
        ),
      ],
    );
  }

  Widget _summary(BuildContext context, Varshphal v) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final when = DateFormat.yMMMd(l10n.localeName).add_jm();
    final toneColor = switch (v.tone) {
      MunthaTone.excellent => AppColors.success,
      MunthaTone.good => AppColors.primary,
      MunthaTone.care => AppColors.textMuted,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.varshphalAge(v.completedYears + 1),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.varshphalPravesh(when.format(v.praveshLocal)),
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Text(
              l10n.varshphalMunthaLine(
                l10n.rashiName(zodiacSigns[v.munthaSign]),
                v.munthaHouse,
              ),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.varshphalTheme(l10n.gocharHouseTheme('h${v.munthaHouse}')),
              key: const ValueKey('varshphalTheme'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: toneColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.varshphalTone(v.tone.name),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _details(BuildContext context, Varshphal v) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = ref.watch(chartStyleProvider);
    final chart = v.chart.rashiChart;

    return [
      Text(l10n.varshphalChart, style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        l10n.varshphalLagna(
          l10n.rashiName(zodiacSigns[v.lagnaSign]),
          l10n.planetName(v.lagnaLord),
        ),
        style: theme.textTheme.bodySmall,
      ),
      Text(
        l10n.varshphalMunthaLord(l10n.planetName(v.munthaLord)),
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      if (chart != null)
        style == ChartStyle.north
            ? RashiChartV2(chart: chart, showHeader: false)
            : SouthIndianChart(chart: chart),
      const SizedBox(height: 16),
      Text(l10n.varshphalPlanets, style: theme.textTheme.titleMedium),
      const SizedBox(height: 6),
      for (final (planet, sign, house) in v.placements)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('${l10n.planetName(planet)} · ${l10n.rashiName(sign)}'),
          subtitle: Text(
            l10n.varshphalPlanetLine(house, l10n.gocharHouseTheme('h$house')),
          ),
        ),
      if (v.months.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(l10n.varshphalMonths, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        for (final (start, house) in v.months)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined, size: 20),
            title: Text(DateFormat.yMMMd(l10n.localeName).format(start)),
            subtitle: Text(
              l10n.varshphalPlanetLine(
                house,
                l10n.gocharHouseTheme('h$house'),
              ),
            ),
          ),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const ValueKey('varshphalPdf'),
        onPressed: _exporting ? null : () => _exportPdf(v),
        icon: _exporting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.picture_as_pdf_outlined),
        label: Text(l10n.varshphalPdf),
      ),
    ];
  }

  Future<void> _exportPdf(Varshphal v) async {
    final l10n = context.l10n;
    final profile = ref.read(birthProfileProvider);
    if (profile == null) return;
    final language = VarshphalPdfService.reportLanguage(
      Localizations.localeOf(context).languageCode,
    );
    setState(() => _exporting = true);
    try {
      final bytes = await const VarshphalPdfService().buildReport(
        name: profile.name,
        place: profile.location.displayName,
        varshphal: v,
        languageCode: language,
      );
      await Printing.layoutPdf(
        name: 'varshphal_${v.completedYears + 1}.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.varshphalPdfUnable)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
