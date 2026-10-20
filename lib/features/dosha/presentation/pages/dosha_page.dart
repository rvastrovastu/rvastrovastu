import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../domain/entities/kaal_sarp_result.dart';
import '../../domain/entities/manglik_result.dart';
import '../../domain/entities/sade_sati.dart';
import '../../domain/entities/zodiac_signs.dart';
import '../../../membership/domain/membership.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../membership/presentation/widgets/premium_gate.dart';
import '../providers/dosha_provider.dart';

class DoshaPage extends ConsumerWidget {
  const DoshaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final report = ref.watch(doshaReportProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.doshaCheckTitle)),
      body: report.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(l10n.doshaCalculating),
            ],
          ),
        ),
        error: (error, _) => _Message(
          icon: Icons.error_outline,
          title: l10n.doshaUnable,
          body: '$error',
          action: FilledButton(
            onPressed: () => ref.invalidate(doshaReportProvider),
            child: Text(l10n.tryAgain),
          ),
        ),
        data: (data) {
          if (data == null) {
            return _Message(
              icon: Icons.person_outline,
              title: l10n.birthProfileRequired,
              body: l10n.doshaCheckSubtitle,
              action: FilledButton.icon(
                onPressed: () => context.go('/birth-profile'),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(l10n.createBirthProfile),
              ),
            );
          }
          return _DoshaReportView(report: data);
        },
      ),
    );
  }
}

class _DoshaReportView extends ConsumerWidget {
  final DoshaReport report;

  const _DoshaReportView({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Manglik stays free; Kaal Sarp and Sade Sati details are Premium.
    final locked = !ref.watch(canUseProvider(PremiumFeature.doshaDetails));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(l10n.doshaIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        _ManglikCard(result: report.manglik),
        const SizedBox(height: 12),
        _KaalSarpCard(result: report.kaalSarp, locked: locked),
        const SizedBox(height: 12),
        _SadeSatiCard(report: report.sadeSati, locked: locked),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.spa_outlined),
            title: Text(l10n.doshaRemediesTitle),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [Text(l10n.doshaRemediesBody)],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.doshaDisclaimer,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Severity used only for colouring the status chip.
enum _Tone { clear, caution, alert }

class _DoshaCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final _Tone tone;
  final List<Widget> children;

  /// Shows the status but hides the details behind Premium.
  final bool locked;

  const _DoshaCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.tone,
    required this.children,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (Color background, Color foreground) = switch (tone) {
      _Tone.clear => (colors.secondaryContainer, colors.onSecondaryContainer),
      _Tone.caution => (colors.tertiaryContainer, colors.onTertiaryContainer),
      _Tone.alert => (colors.errorContainer, colors.onErrorContainer),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (locked)
              const PremiumUnlockRow(feature: PremiumFeature.doshaDetails)
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

class _ManglikCard extends StatelessWidget {
  final ManglikResult result;

  const _ManglikCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final tone = switch (result.status) {
      ManglikStatus.none || ManglikStatus.cancelled => _Tone.clear,
      ManglikStatus.mild => _Tone.caution,
      ManglikStatus.present => _Tone.alert,
    };

    return _DoshaCard(
      icon: Icons.local_fire_department_outlined,
      title: l10n.manglikTitle,
      status: l10n.doshaStatus(result.status.name),
      tone: tone,
      children: [
        Text(l10n.manglikSummary(result.status.name)),
        for (final reason in result.cancellations)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(l10n.manglikCancellation(reason.name))),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Text(
          l10n.manglikMarsPosition(
            l10n.rashiName(result.marsSign),
            result.marsHouseFromLagna,
            result.marsHouseFromMoon,
            result.marsHouseFromVenus,
          ),
          style: theme.textTheme.bodySmall,
        ),
        if (result.hasManglikPlacement) ...[
          const SizedBox(height: 10),
          Text(l10n.manglikMatchingTip, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _KaalSarpCard extends StatelessWidget {
  final KaalSarpResult result;
  final bool locked;

  const _KaalSarpCard({required this.result, required this.locked});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final (String status, _Tone tone) = switch (result.status) {
      KaalSarpStatus.none => (l10n.doshaStatus('none'), _Tone.clear),
      KaalSarpStatus.partial => (l10n.doshaStatus('partial'), _Tone.caution),
      KaalSarpStatus.full => (l10n.doshaStatus('present'), _Tone.alert),
    };

    final String summary = switch (result.status) {
      KaalSarpStatus.none => l10n.kaalSarpSummaryNone,
      KaalSarpStatus.full => l10n.kaalSarpSummaryFull(
        result.rahuHouse,
        result.ketuHouse,
      ),
      KaalSarpStatus.partial => l10n.kaalSarpSummaryPartial(
        result.planetsOutside.map(l10n.planetName).join(', '),
      ),
    };

    return _DoshaCard(
      icon: Icons.all_inclusive,
      title: l10n.kaalSarpTitle,
      status: status,
      tone: tone,
      locked: locked,
      children: [
        if (result.type != null) ...[
          Text(
            l10n.kaalSarpType(result.type!.name),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
        ],
        Text(summary),
        if (result.direction == KaalSarpDirection.ketuToRahu) ...[
          const SizedBox(height: 8),
          Text(l10n.kaalSarpAmritNote, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _SadeSatiCard extends StatelessWidget {
  final SadeSatiReport report;
  final bool locked;

  const _SadeSatiCard({required this.report, required this.locked});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd(l10n.localeName);
    String date(DateTime value) => dateFormat.format(value.toLocal());

    final current = report.currentCycle;
    final next = report.nextCycle;
    final now = DateTime.now();
    final past = report.cycles
        .where((cycle) => cycle != current && cycle.end.isBefore(now))
        .toList();

    final String status;
    final _Tone tone;
    if (current != null) {
      status = l10n.doshaStatus('active');
      tone = report.currentPhase == SadeSatiPhase.peak
          ? _Tone.alert
          : _Tone.caution;
    } else if (report.currentDhaiya != null) {
      status = l10n.doshaStatus('mild');
      tone = _Tone.caution;
    } else {
      status = l10n.doshaStatus('none');
      tone = _Tone.clear;
    }

    final saturnIndex = report.saturnSignIndex;

    return _DoshaCard(
      icon: Icons.brightness_3_outlined,
      title: l10n.sadeSatiTitle,
      status: status,
      tone: tone,
      locked: locked,
      children: [
        Text(
          l10n.sadeSatiBasis(l10n.rashiName(report.moonSign)),
          style: theme.textTheme.bodySmall,
        ),
        if (saturnIndex != null)
          Text(
            l10n.sadeSatiSaturnNow(l10n.rashiName(zodiacSigns[saturnIndex])),
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 10),
        if (current != null) ...[
          Text(
            report.currentPhase == null
                ? l10n.sadeSatiPaused
                : l10n.sadeSatiActive(
                    l10n.sadeSatiPhase(report.currentPhase!.name),
                  ),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.sadeSatiCurrentCycle(date(current.start), date(current.end)),
          ),
          const SizedBox(height: 10),
          _PhaseTimeline(
            cycle: current,
            activePhase: report.currentPhase,
            formatDate: date,
          ),
        ] else
          Text(l10n.sadeSatiNotActive, style: theme.textTheme.titleSmall),
        if (report.currentDhaiya != null) ...[
          const SizedBox(height: 10),
          Text(l10n.shaniDhaiya(report.currentDhaiya!.name)),
        ],
        if (next != null) ...[
          const SizedBox(height: 10),
          Text(l10n.sadeSatiNextCycle(date(next.start), date(next.end))),
        ],
        if (past.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(l10n.sadeSatiPastCycles, style: theme.textTheme.labelLarge),
          for (final cycle in past)
            Text(
              '${date(cycle.start)} – ${date(cycle.end)}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}

class _PhaseTimeline extends StatelessWidget {
  final SadeSatiCycle cycle;
  final SadeSatiPhase? activePhase;
  final String Function(DateTime) formatDate;

  const _PhaseTimeline({
    required this.cycle,
    required this.activePhase,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        for (final phase in SadeSatiPhase.values)
          if (cycle.phaseStart(phase) case final start?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    phase == activePhase
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: phase == activePhase
                        ? colors.primary
                        : colors.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.sadeSatiPhaseDetail(phase.name)} · '
                      '${l10n.sadeSatiPhaseFrom(formatDate(start))}',
                      style: phase == activePhase
                          ? theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            )
                          : theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget action;

  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            action,
          ],
        ),
      ),
    );
  }
}
