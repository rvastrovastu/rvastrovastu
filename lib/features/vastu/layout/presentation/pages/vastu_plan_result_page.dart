import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../../core/l10n/l10n_extension.dart';
import '../../../../../core/localization/language_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../membership/domain/membership.dart';
import '../../../../membership/presentation/providers/membership_provider.dart';
import '../../../../membership/presentation/widgets/premium_gate.dart';
import '../../../domain/entities/vastu_zone.dart';
import '../../../presentation/utils/vastu_localization.dart';
import '../../data/vastu_report_pdf_service.dart';
import '../../domain/vastu_analysis.dart';
import '../../domain/vastu_layout.dart';
import '../vastu_layout_providers.dart';
import '../vastu_layout_text.dart';
import '../widgets/plan_canvas.dart';

/// Image file for a saved plan, or null.
final vastuPlanImageProvider = FutureProvider.family<File?, String>(
  (ref, name) => ref.watch(vastuImageStoreProvider).file(name),
);

/// Builds the detailed report for a property and opens the system
/// print/share sheet. Replaced in tests.
final vastuReportExporterProvider = Provider<Future<void> Function(VastuLayout)>(
  (ref) => (layout) async {
    // The PDF font covers Latin and Devanagari scripts.
    final code = ref.read(languageProvider).code;
    final l10n = lookupAppLocalizations(
      Locale(const {'hi', 'mr'}.contains(code) ? code : 'en'),
    );
    final image = layout.imageFile == null
        ? null
        : await ref.read(vastuImageStoreProvider).file(layout.imageFile!);
    final bytes = await const VastuReportPdfService().build(
      layout: layout,
      l10n: l10n,
      planImage: await image?.readAsBytes(),
    );
    await Printing.layoutPdf(
      name: 'vastu_${layout.name.replaceAll(RegExp(r'\s+'), '_')}.pdf',
      onLayout: (_) async => bytes,
    );
  },
);

/// Score, doshas and placements for one property; remedies and the full
/// grid for Premium; the detailed PDF report as a per-property purchase.
class VastuPlanResultPage extends ConsumerWidget {
  final String layoutId;

  const VastuPlanResultPage({super.key, required this.layoutId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layout = ref.watch(vastuLayoutProvider(layoutId));

    return layout.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(body: Center(child: Text(l10n.vastuPlansEmpty))),
      data: (layout) => layout == null
          ? Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(l10n.vastuPlansEmpty)),
            )
          : _Result(layout: layout),
    );
  }
}

class _Result extends ConsumerWidget {
  final VastuLayout layout;

  const _Result({required this.layout});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.vastuPlanDeleteConfirm(layout.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.vastuPlanDelete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(vastuLayoutsProvider.notifier).delete(layout.id);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final analysis = VastuAnalysis.of(layout);
    final premium = ref.watch(canUseProvider(PremiumFeature.vastuRemedies));
    final image = layout.imageFile == null
        ? null
        : ref.watch(vastuPlanImageProvider(layout.imageFile!)).value;
    final minor = analysis.doshas.length - analysis.majorCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(layout.name),
        actions: [
          IconButton(
            tooltip: l10n.vastuPlanEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/vastu/plans/${layout.id}/edit'),
          ),
          IconButton(
            tooltip: l10n.vastuPlanDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ScoreCard(analysis: analysis, minor: minor),
          const SizedBox(height: 16),
          PlanCanvas(
            layout: layout,
            image: image,
            showGrid: premium,
            fits: {for (final r in analysis.rooms) r.mark.id: r.fit},
            onTap: premium
                ? (p) => _showZone(context, layout.placeOf(p))
                : null,
          ),
          const SizedBox(height: 8),
          if (premium)
            Text(l10n.vastuGridHelp, style: theme.textTheme.bodySmall)
          else
            const PremiumUnlockRow(feature: PremiumFeature.vastuRemedies),

          _SectionTitle(l10n.vastuDoshasTitle),
          if (analysis.doshas.isEmpty)
            Text(l10n.vastuDoshasNone)
          else
            for (final dosha in analysis.doshas)
              _DoshaTile(dosha: dosha, showRemedy: premium),

          if (analysis.rooms.isNotEmpty) ...[
            _SectionTitle(l10n.vastuPlacementsTitle),
            Card(
              child: Column(
                children: [
                  for (final r in analysis.rooms)
                    ListTile(
                      dense: true,
                      leading: Icon(roomIcon(r.room)),
                      title: Text(l10n.roomName(r.room)),
                      subtitle: Text(l10n.placeName(r.place)),
                      trailing: _FitChip(fit: r.fit),
                    ),
                ],
              ),
            ),
          ],

          _SectionTitle(l10n.vastuRemediesTitle),
          if (premium) ...[
            if (analysis.doshas.isNotEmpty)
              Text(l10n.vastuRemediesIntro, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.vastuGeneralUpayTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(l10n.vastuGeneralUpay),
                  ],
                ),
              ),
            ),
          ] else
            const PremiumLockedCard(feature: PremiumFeature.vastuRemedies),

          _SectionTitle(l10n.vastuReportTitle),
          _ReportCard(layout: layout),
          const SizedBox(height: 16),
          Text(
            l10n.vastuReportDisclaimer,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showZone(BuildContext context, ZonePlace place) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.placeName(place), style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (place.zone case final VastuZone zone) ...[
              Text(l10n.vastuZoneTheme(zone.name)),
              const SizedBox(height: 10),
              Text(l10n.vastuBestFor, style: theme.textTheme.labelLarge),
              Text(l10n.vastuZoneBest(zone.name)),
              const SizedBox(height: 8),
              Text(l10n.vastuAvoid, style: theme.textTheme.labelLarge),
              Text(l10n.vastuZoneAvoid(zone.name)),
            ] else
              Text(l10n.vastuDoshaCentre),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _ScoreCard extends StatelessWidget {
  final VastuAnalysis analysis;
  final int minor;

  const _ScoreCard({required this.analysis, required this.minor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = switch (analysis.band) {
      VastuScoreBand.excellent || VastuScoreBand.good => AppColors.success,
      VastuScoreBand.average => AppColors.warning,
      VastuScoreBand.attention => AppColors.error,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Text(
                  '${analysis.score}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text('/ 100', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.vastuScoreTitle, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(l10n.vastuScoreBand(analysis.band.name)),
                  const SizedBox(height: 8),
                  Text(
                    l10n.vastuDoshaCounts(analysis.majorCount, minor),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.vastuEntranceResult(l10n.padaLabel(analysis.entrancePada))} · '
                    '${localizedVastuLevel(l10n, analysis.entranceLevel)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FitChip extends StatelessWidget {
  final ZoneFit fit;

  const _FitChip({required this.fit});

  @override
  Widget build(BuildContext context) {
    final color = switch (fit) {
      ZoneFit.ideal => AppColors.success,
      ZoneFit.acceptable => AppColors.warning,
      ZoneFit.avoid => AppColors.error,
    };
    return Text(
      context.l10n.vastuFit(fit.name),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DoshaTile extends StatelessWidget {
  final VastuDosha dosha;
  final bool showRemedy;

  const _DoshaTile({required this.dosha, required this.showRemedy});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final major = dosha.severity == DoshaSeverity.major;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: major ? AppColors.error : AppColors.warning,
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.doshaTitle(dosha),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  l10n.vastuSeverity(dosha.severity.name),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: major ? AppColors.error : AppColors.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (l10n.doshaDetail(dosha) case final detail?) ...[
              const SizedBox(height: 4),
              Text(detail, style: theme.textTheme.bodySmall),
            ],
            if (showRemedy) ...[
              const SizedBox(height: 10),
              Text(l10n.vastuRemedyLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(l10n.remedyFor(dosha)),
              if (l10n.suggestionFor(dosha) case final move?) ...[
                const SizedBox(height: 6),
                Text(
                  move,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Buy, claim or download the detailed report for this property.
class _ReportCard extends ConsumerStatefulWidget {
  final VastuLayout layout;

  const _ReportCard({required this.layout});

  @override
  ConsumerState<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<_ReportCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _download() async {
    final ui = context.l10n;
    try {
      await ref.read(vastuReportExporterProvider)(widget.layout);
    } catch (error) {
      debugPrint('[VASTU REPORT] $error');
      if (mounted) _toast(ui.vastuReportUnable);
    }
  }

  Future<void> _buy(VastuReportOffer offer) async {
    final l10n = context.l10n;
    final outcome = await ref
        .read(membershipProvider.notifier)
        .buyVastuReport(offer);
    switch (outcome) {
      case PurchaseOutcome.purchased:
        if (await useReportCredit(ref, widget.layout.id)) await _download();
      case PurchaseOutcome.pending:
        if (mounted) _toast(l10n.premiumPending);
      case PurchaseOutcome.failed:
        if (mounted) _toast(l10n.premiumFailed);
      case PurchaseOutcome.cancelled:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final access = ref.watch(vastuReportAccessProvider(widget.layout.id));
    final offer = ref.watch(vastuReportOfferProvider).value;

    final Widget action = switch (access) {
      VastuReportAccess.unlocked => FilledButton.icon(
        onPressed: _busy ? null : () => _run(_download),
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: Text(l10n.vastuReportDownload),
      ),
      VastuReportAccess.unusedCredit => FilledButton.icon(
        onPressed: _busy
            ? null
            : () => _run(() async {
                if (await useReportCredit(ref, widget.layout.id)) {
                  await _download();
                }
              }),
        icon: const Icon(Icons.redeem_outlined),
        label: Text(l10n.vastuReportUseCredit),
      ),
      VastuReportAccess.locked =>
        offer == null
            ? Text(
                l10n.vastuReportUnavailable,
                style: theme.textTheme.bodySmall,
              )
            : FilledButton.icon(
                onPressed: _busy ? null : () => _run(() => _buy(offer)),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text(l10n.vastuReportBuy(offer.priceLabel)),
              ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.vastuReportTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.vastuReportPitch),
            const SizedBox(height: 6),
            Text(
              l10n.vastuReportOnePerProperty,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              action,
          ],
        ),
      ),
    );
  }
}
