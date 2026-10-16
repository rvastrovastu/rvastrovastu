import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/domain/entities/rashi_chart.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../domain/usecases/calculate_navamsa.dart';
import '../providers/chart_style_provider.dart';
import 'rashi_chart/rashi_chart_v2.dart';
import 'rashi_chart/south_indian_chart.dart';

enum _Division { d1, d9 }

/// Birth chart (D1) and Navamsa (D9), in North or South Indian style.
class KundaliChartsCard extends ConsumerStatefulWidget {
  final Kundali kundali;

  const KundaliChartsCard({super.key, required this.kundali});

  @override
  ConsumerState<KundaliChartsCard> createState() => _KundaliChartsCardState();
}

class _KundaliChartsCardState extends ConsumerState<KundaliChartsCard> {
  _Division _division = _Division.d1;
  NavamsaChart? _navamsa;

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
    if (oldWidget.kundali != widget.kundali) _navamsa = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = ref.watch(chartStyleProvider);

    final navamsa = _division == _Division.d9 ? _navamsaChart : null;
    final RashiChart? chart = _division == _Division.d1
        ? widget.kundali.rashiChart
        : navamsa?.chart;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<_Division>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: _Division.d1, label: Text(l10n.chartD1)),
                ButtonSegment(value: _Division.d9, label: Text(l10n.chartD9)),
              ],
              selected: {_division},
              onSelectionChanged: (value) =>
                  setState(() => _division = value.first),
            ),
            const SizedBox(height: 10),
            Text(
              _division == _Division.d1
                  ? l10n.chartD1Subtitle
                  : l10n.chartD9Subtitle,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            if (chart == null)
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
