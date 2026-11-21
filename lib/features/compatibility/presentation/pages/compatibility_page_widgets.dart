// The match result: koota rows, Manglik comparison, label helpers and
// the shareable card.
part of 'compatibility_page.dart';

class _CompatibilityResultView extends StatelessWidget {
  final CompatibilityResult result;
  final String Function(double) formatScore;

  /// Free users see the total score; the koota breakdown is Premium.
  final bool detailsLocked;

  /// The two people, for the share card.
  final (String, String) names;

  const _CompatibilityResultView({
    required this.result,
    required this.formatScore,
    this.names = ('', ''),
    this.detailsLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final rankedKootas = [...result.kootas]
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '${formatScore(result.totalScore)} / '
                  '${formatScore(result.maximumScore)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(l10n.compatScoreLabel),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: result.maximumScore <= 0
                      ? 0
                      : (result.totalScore / result.maximumScore)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                ),
                const SizedBox(height: 12),
                Text(
                  result.meetsTraditionalMinimum
                      ? l10n.compatMeetsThreshold
                      : l10n.compatBelowThreshold,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('compatShare'),
                      onPressed: () => showShareCardSheet(
                        context,
                        card: BrandedShareCard(
                          child: _MatchShareContent(
                            names: names,
                            score:
                                '${formatScore(result.totalScore)} / '
                                '${formatScore(result.maximumScore)}',
                            meets: result.meetsTraditionalMinimum,
                          ),
                        ),
                        fileName: 'kundali_match',
                        text: l10n.shareInvite(appShareUrl),
                      ),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(l10n.shareButton),
                    ),
                    Builder(
                      builder: (buttonContext) => TextButton.icon(
                        onPressed: () => shareText(
                          buttonContext,
                          text: l10n.shareInvite(appShareUrl),
                          subject: l10n.compatTitle,
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(l10n.compatInviteFriend),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (detailsLocked) ...[
          const SizedBox(height: 16),
          const PremiumLockedCard(
            feature: PremiumFeature.compatibilityDetails,
          ),
        ] else ...[
        const SizedBox(height: 16),
        Text(
          l10n.compatEightKootas,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (rankedKootas.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.compatInsightsTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.compatInsightsBody,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _KootaInsightRow(
                    label: l10n.compatHighest,
                    name: l10n.compatHighestName,
                    percentage: rankedKootas.first.percentage,
                  ),
                  if (rankedKootas.length > 1) ...[
                    const SizedBox(height: 10),
                    _KootaInsightRow(
                      label: l10n.compatLowest,
                      name: l10n.compatLowestName,
                      percentage: rankedKootas.last.percentage,
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        ...result.kootas.map(
          (koota) => Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          kootaLabel(l10n, koota),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${formatScore(koota.score)} / '
                        '${formatScore(koota.maximum)}',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(kootaDescription(l10n, koota)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: koota.percentage / 100),
                ],
              ),
            ),
          ),
        ),
        if (result.traditionalFlags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.compatFlagsTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...result.traditionalFlags.map(
            (flag) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(flagText(l10n, flag)),
            ),
          ),
          Text(
            l10n.compatFlagsNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        ],
      ],
    );
  }
}

class _KootaInsightRow extends StatelessWidget {
  final String label;
  final String name;
  final double percentage;

  const _KootaInsightRow({
    required this.label,
    required this.name,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final formattedPercentage = percentage.toStringAsFixed(
      percentage == percentage.roundToDouble() ? 0 : 1,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.insights_outlined, color: colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(name, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        Text(
          '$formattedPercentage%',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ManglikComparison {
  final ManglikResult bride;
  final ManglikResult groom;

  const _ManglikComparison({required this.bride, required this.groom});

  ManglikMatch get match => compareManglik(bride, groom);
}

class _ManglikMatchCard extends StatelessWidget {
  final _ManglikComparison comparison;

  const _ManglikMatchCard({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (String summary, IconData icon, Color color) =
        switch (comparison.match) {
          ManglikMatch.neitherManglik => (
            l10n.compatManglikNeither,
            Icons.check_circle_outline,
            colors.primary,
          ),
          ManglikMatch.bothManglik => (
            l10n.compatManglikBoth,
            Icons.balance,
            colors.primary,
          ),
          ManglikMatch.onlyOneManglik => (
            l10n.compatManglikOnlyOne,
            Icons.info_outline,
            colors.tertiary,
          ),
        };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  l10n.compatManglikTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(summary),
            const SizedBox(height: 10),
            Text(
              l10n.compatManglikPerson(
                l10n.compatPerson('bride'),
                l10n.compatManglikStatus(comparison.bride.status.name),
              ),
            ),
            Text(
              l10n.compatManglikPerson(
                l10n.compatPerson('groom'),
                l10n.compatManglikStatus(comparison.groom.status.name),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ARB key for a Koota name from the domain ('Graha Maitri' → grahaMaitri).
String _kootaKey(String name) {
  final words = name.trim().toLowerCase().split(RegExp(r'\s+'));
  return words.first +
      words.skip(1).map((w) => w[0].toUpperCase() + w.substring(1)).join();
}

String kootaLabel(AppLocalizations l10n, KootaScore koota) =>
    l10n.kootaName(_kootaKey(koota.name));

/// English keeps the calculation's own explanation; other languages use the
/// translated summary for that Koota.
String kootaDescription(AppLocalizations l10n, KootaScore koota) =>
    l10n.localeName.startsWith('en')
    ? koota.explanation
    : l10n.kootaExplanation(_kootaKey(koota.name));

String flagText(AppLocalizations l10n, String flag) {
  if (l10n.localeName.startsWith('en')) return flag;
  if (flag.startsWith('Traditional Nadi')) return l10n.compatFlag('nadi');
  if (flag.startsWith('Traditional Bhakoot')) {
    return l10n.compatFlag('bhakoot');
  }
  return flag;
}

/// Two names and the guna score, as a share image.
class _MatchShareContent extends StatelessWidget {
  final (String, String) names;
  final String score;
  final bool meets;

  const _MatchShareContent({
    required this.names,
    required this.score,
    required this.meets,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (a, b) = names;
    return Column(
      children: [
        Text(l10n.compatTitle, style: theme.textTheme.labelLarge),
        const SizedBox(height: 10),
        if (a.isNotEmpty || b.isNotEmpty)
          Text(
            '$a  ♥  $b',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        const SizedBox(height: 10),
        Text(
          score,
          style: theme.textTheme.displaySmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(l10n.compatScoreLabel, style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        Text(
          meets ? l10n.compatMeetsThreshold : l10n.compatBelowThreshold,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
