import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../domain/entities/yoga.dart';
import '../../domain/usecases/detect_yogas.dart';

/// "Yogas in your chart" — supportive yogas first, then challenging ones.
class YogasCard extends StatelessWidget {
  final Kundali kundali;

  const YogasCard({super.key, required this.kundali});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    List<YogaResult> yogas;
    try {
      yogas = const DetectYogas()(kundali);
    } on ArgumentError {
      return const SizedBox.shrink();
    }

    yogas.sort((a, b) => a.id.nature.index.compareTo(b.id.nature.index));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.yogasTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l10n.yogasIntro, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            if (yogas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l10n.yogasNone),
              ),
            for (final yoga in yogas) _YogaTile(yoga: yoga),
          ],
        ),
      ),
    );
  }
}

class _YogaTile extends StatelessWidget {
  final YogaResult yoga;

  const _YogaTile({required this.yoga});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final supportive = yoga.id.nature == YogaNature.supportive;

    final color = yoga.cancelled
        ? AppColors.textMuted
        : supportive
        ? AppColors.primary
        : AppColors.error;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: Icon(
          supportive ? Icons.auto_awesome : Icons.do_not_disturb_on_outlined,
          color: color,
        ),
        title: Text(
          l10n.chartYogaName(yoga.id.name),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          [
            yoga.planets.map(l10n.planetName).join(' + '),
            if (yoga.cancelled) l10n.chartYogaCancelled,
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        children: [
          Text(l10n.chartYogaMeaning(yoga.id.name)),
          const SizedBox(height: 6),
          Text(
            l10n.chartYogaRule(yoga.id.name),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
