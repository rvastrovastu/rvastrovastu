import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../membership/domain/membership.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../membership/presentation/widgets/premium_gate.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/domain/entities/rashi_chart.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../domain/usecases/calculate_navamsa.dart';
import '../../domain/usecases/calculate_varga.dart';
import '../providers/chart_style_provider.dart';
import 'rashi_chart/rashi_chart_v2.dart';
import 'rashi_chart/south_indian_chart.dart';

/// The birth chart, the Moon chart and the divisional charts (D2–D60),
/// in North or South Indian style. D1 and the Moon chart are free.
class KundaliChartsCard extends ConsumerStatefulWidget {
  final Kundali kundali;

  const KundaliChartsCard({super.key, required this.kundali});

  @override
  ConsumerState<KundaliChartsCard> createState() => _KundaliChartsCardState();
}

class _KundaliChartsCardState extends ConsumerState<KundaliChartsCard> {
  Varga _varga = Varga.d1;
  final _charts = <Varga, VargaChart?>{};
  NavamsaChart? _navamsa;

  VargaChart? _chartFor(Varga varga) => _charts.putIfAbsent(varga, () {
    try {
      return const CalculateVarga()(widget.kundali, varga);
    } on ArgumentError {
      return null;
    }
  });

  NavamsaChart? get _navamsaChart {
    try {
      return _navamsa ??= const CalculateNavamsa()(widget.kundali);
    } on ArgumentError {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant KundaliChartsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kundali != widget.kundali) {
      _charts.clear();
      _navamsa = null;
    }
  }

  PremiumFeature? _featureFor(Varga varga) => varga.isFree
      ? null
      : varga == Varga.d9
      ? PremiumFeature.navamsa
      : PremiumFeature.vargaCharts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = ref.watch(chartStyleProvider);

    bool locked(Varga v) {
      final feature = _featureFor(v);
      return feature != null && !ref.watch(canUseProvider(feature));
    }

    final feature = _featureFor(_varga);
    final isLocked = locked(_varga);
    final RashiChart? chart = isLocked
        ? null
        : _varga == Varga.d1
        ? widget.kundali.rashiChart
        : _chartFor(_varga)?.chart;
    final navamsa = _varga == Varga.d9 && !isLocked ? _navamsaChart : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final v in Varga.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        key: ValueKey('varga-${v.name}'),
                        label: Text(l10n.chartVargaChip(v.name)),
                        avatar: locked(v)
                            ? const Icon(Icons.lock_outline_rounded, size: 16)
                            : null,
                        selected: _varga == v,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _varga = v),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.chartVargaName(_varga.name),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.chartVargaAbout(_varga.name),
              style: theme.textTheme.bodySmall,
            ),
            if (_varga.division >= 16) ...[
              const SizedBox(height: 4),
              Text(
                l10n.chartVargaPrecision,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (isLocked)
              PremiumLockedCard(feature: feature!)
            else if (chart == null)
              Text(l10n.unableToCalculateKundali)
            else if (style == ChartStyle.north)
              RashiChartV2(chart: chart, showHeader: false)
            else
              SouthIndianChart(chart: chart),
            if (navamsa != null && navamsa.vargottama.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.chartVargottama(
                  navamsa.vargottama.map(l10n.planetName).join(', '),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => ref
                    .read(chartStyleProvider.notifier)
                    .set(
                      style == ChartStyle.north
                          ? ChartStyle.south
                          : ChartStyle.north,
                    ),
                icon: const Icon(Icons.swap_horiz),
                label: Text(
                  style == ChartStyle.north
                      ? l10n.chartShowSouth
                      : l10n.chartShowNorth,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
