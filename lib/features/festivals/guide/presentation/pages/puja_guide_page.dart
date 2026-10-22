import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../../core/l10n/l10n_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../membership/domain/membership.dart';
import '../../../../membership/presentation/providers/membership_provider.dart';
import '../../../../membership/presentation/widgets/premium_gate.dart';
import '../../../domain/entities/calendar_observance.dart';
import '../../../presentation/widgets/observance_tile.dart';
import '../../data/puja_guide_repository.dart';
import '../../domain/puja_guide.dart';
import '../../domain/puja_guide_spec.dart';
import '../../domain/puja_timing.dart';
import '../puja_guide_providers.dart';

/// What to do on a festival or vrat: about, do's and don'ts, samagri and
/// aarti for everyone; the full vidhi, mantras, katha and timing for
/// Premium.
class PujaGuidePage extends ConsumerWidget {
  final ObservanceId id;

  /// The date the observance falls on, for the puja timing.
  final DateTime? date;

  const PujaGuidePage({super.key, required this.id, this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final guides = ref.watch(pujaGuidesProvider(lang));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.festivalName(id.name)),
          bottom: TabBar(
            tabs: [
              for (final tab in const ['about', 'vidhi', 'aarti'])
                Tab(text: l10n.pujaGuideTab(tab)),
            ],
          ),
        ),
        body: guides.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.pujaGuideUnavailable, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.invalidate(pujaGuidesProvider(lang)),
                    child: Text(l10n.tryAgain),
                  ),
                ],
              ),
            ),
          ),
          data: (all) {
            final guide = all[id];
            if (guide == null) {
              return Center(child: Text(l10n.pujaGuideUnavailable));
            }
            final spec = pujaGuideSpecs[id] ?? const PujaGuideSpec();
            return TabBarView(
              children: [
                _AboutTab(
                  guide: guide,
                  date: date,
                  translated: PujaGuideRepository.guideLanguage(lang) == lang,
                ),
                _VidhiTab(guide: guide, spec: spec, date: date),
                _AartiTab(keys: spec.aartis),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// About (free)

class _AboutTab extends StatelessWidget {
  final PujaGuide guide;
  final DateTime? date;
  final bool translated;

  const _AboutTab({required this.guide, this.date, required this.translated});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final when = date == null
        ? null
        : DateFormat.yMMMMEEEEd(l10n.localeName).format(date!);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  observanceIcon(guide.id),
                  size: 36,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pujaGuideDeity(guide.deity),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (when != null) ...[
                        const SizedBox(height: 4),
                        Text(when, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!translated) ...[
          const SizedBox(height: 8),
          Text(l10n.pujaGuideLanguageNote, style: theme.textTheme.bodySmall),
        ],
        _Section(title: l10n.pujaGuideSection('about'), text: guide.about),
        _Section(
          title: l10n.pujaGuideSection('benefits'),
          child: _Bullets(
            guide.benefits,
            icon: Icons.auto_awesome,
            color: AppColors.primary,
          ),
        ),
        _Section(
          title: l10n.pujaGuideSection('dos'),
          child: _Bullets(
            guide.dos,
            icon: Icons.check_circle_outline,
            color: AppColors.success,
          ),
        ),
        _Section(
          title: l10n.pujaGuideSection('donts'),
          child: _Bullets(
            guide.donts,
            icon: Icons.do_not_disturb_on_outlined,
            color: AppColors.error,
          ),
        ),
        _Section(title: l10n.pujaGuideSection('fasting'), text: guide.fasting),
        _Section(
          title: l10n.pujaGuideSection('samagri'),
          child: _SamagriChecklist(items: guide.samagri),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.pujaGuideDisclaimer,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SamagriChecklist extends StatefulWidget {
  final List<String> items;

  const _SamagriChecklist({required this.items});

  @override
  State<_SamagriChecklist> createState() => _SamagriChecklistState();
}

class _SamagriChecklistState extends State<_SamagriChecklist> {
  final _ready = <int>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.pujaGuideSamagriProgress(
                      _ready.length,
                      widget.items.length,
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
          for (final (i, item) in widget.items.indexed)
            CheckboxListTile(
              value: _ready.contains(i),
              onChanged: (v) => setState(
                () => v == true ? _ready.add(i) : _ready.remove(i),
              ),
              title: Text(item),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vidhi (Premium)

class _VidhiTab extends ConsumerWidget {
  final PujaGuide guide;
  final PujaGuideSpec spec;
  final DateTime? date;

  const _VidhiTab({required this.guide, required this.spec, this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final premium = ref.watch(canUseProvider(PremiumFeature.pujaVidhi));

    if (!premium) {
      // A taste of the vidhi, then the lock.
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SectionTitle(l10n.pujaGuideSection('steps')),
          _Step(number: 1, text: guide.steps.first),
          const SizedBox(height: 8),
          Text(
            l10n.pujaGuideStepsPreview(guide.steps.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const PremiumLockedCard(feature: PremiumFeature.pujaVidhi),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (date != null) _TimingCard(id: guide.id, date: date!),
        _SectionTitle(l10n.pujaGuideSection('steps')),
        for (final (i, step) in guide.steps.indexed)
          _Step(number: i + 1, text: step),
        if (spec.mantras.isNotEmpty) ...[
          _SectionTitle(l10n.pujaGuideSection('mantras')),
          for (final (i, mantra) in spec.mantras.indexed)
            _MantraCard(
              mantra: mantra,
              meaning: i < guide.mantraMeanings.length
                  ? guide.mantraMeanings[i]
                  : null,
            ),
        ],
        _Section(title: l10n.pujaGuideSection('story'), text: guide.story),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: AppColors.primary,
          child: Text(
            '$number',
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _MantraCard extends StatelessWidget {
  final Mantra mantra;
  final String? meaning;

  const _MantraCard({required this.mantra, this.meaning});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mantra.devanagari,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.primaryLight,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mantra.latin,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            if (meaning != null) ...[
              const Divider(height: 20),
              Text(meaning!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimingCard extends ConsumerWidget {
  final ObservanceId id;
  final DateTime date;

  const _TimingCard({required this.id, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final timing = ref.watch(pujaTimingProvider((id: id, date: date)));

    Widget body(PujaTiming? t) {
      if (t == null) return Text(l10n.festivalLocationNeeded);
      final zone = tz.getLocation(t.timezone);
      String time(DateTime utc) => MaterialLocalizations.of(context)
          .formatTimeOfDay(TimeOfDay.fromDateTime(tz.TZDateTime.from(utc, zone)));
      String range(TimeWindow w) => '${time(w.start)} – ${time(w.end)}';
      final moonrise = switch (t.moonrise?.trim()) {
        final m? when m.isNotEmpty && m != '—' => m,
        _ => null,
      };

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pujaGuideTimingAt(
              DateFormat.MMMEd(l10n.localeName).format(date),
              t.city ?? l10n.pujaGuideYourLocation,
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.pujaGuideWindow(t.rule.name),
            style: theme.textTheme.labelLarge,
          ),
          if (t.window != null)
            Text(
              range(t.window!),
              key: const ValueKey('pujaWindow'),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (t.rule == PujaTimeRule.moonrise)
            Text(
              moonrise != null
                  ? l10n.pujaGuideMoonrise(moonrise)
                  : l10n.pujaGuideMoonriseUnknown,
              style: theme.textTheme.bodyMedium,
            ),
          for (final clash in t.clashes)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.pujaGuideClash(l10n.pujaGuidePeriod(clash)),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          if (t.avoid.isNotEmpty) ...[
            const Divider(height: 24),
            Text(l10n.pujaGuideAvoid, style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final (key, window) in t.avoid)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.pujaGuidePeriod(key))),
                    Text(range(window)),
                  ],
                ),
              ),
          ],
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.primary, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.pujaGuideSection('timing'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            timing.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(l10n.homeUnableToCalculatePanchang),
              data: body,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aarti (free)

class _AartiTab extends ConsumerStatefulWidget {
  final List<String> keys;

  const _AartiTab({required this.keys});

  @override
  ConsumerState<_AartiTab> createState() => _AartiTabState();
}

class _AartiTabState extends ConsumerState<_AartiTab> {
  bool _devanagari = true;
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    if (widget.keys.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.pujaGuideNoAarti, textAlign: TextAlign.center),
      );
    }

    final library = ref.watch(aartiLibraryProvider);
    return library.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l10n.pujaGuideUnavailable)),
      data: (aartis) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(l10n.pujaGuideScript('devanagari')),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.pujaGuideScript('latin')),
                    ),
                  ],
                  selected: {_devanagari},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _devanagari = s.first),
                ),
              ),
              IconButton(
                tooltip: l10n.pujaGuideTextSize,
                onPressed: _scale > 1.0
                    ? () => setState(() => _scale -= 0.2)
                    : null,
                icon: const Icon(Icons.text_decrease_rounded),
              ),
              IconButton(
                key: const ValueKey('aartiLarger'),
                tooltip: l10n.pujaGuideTextSize,
                onPressed: _scale < 1.99
                    ? () => setState(() => _scale += 0.2)
                    : null,
                icon: const Icon(Icons.text_increase_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final key in widget.keys)
            if (aartis[key] case final aarti?)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _devanagari ? aarti.titleDevanagari : aarti.titleLatin,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        (_devanagari ? aarti.devanagari : aarti.latin).join(
                          '\n',
                        ),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize:
                              (theme.textTheme.bodyLarge?.fontSize ?? 16) *
                              _scale,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final String? text;
  final Widget? child;

  const _Section({required this.title, this.text, this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(title),
      if (text != null)
        Text(
          text!,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ?child,
    ],
  );
}

class _Bullets extends StatelessWidget {
  final List<String> items;
  final IconData icon;
  final Color color;

  const _Bullets(this.items, {required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(item)),
            ],
          ),
        ),
    ],
  );
}
