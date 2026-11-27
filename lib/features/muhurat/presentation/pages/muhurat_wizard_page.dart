import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../../panchang/presentation/providers/daily_panchang_provider.dart';
import '../../../panchang/presentation/providers/panchang_location_provider.dart';
import '../../../panchang/presentation/utils/panchang_localization.dart';
import '../../../your_day/domain/day_strength.dart';
import '../../domain/services/muhurat_candidate_search_service.dart';

/// The purposes the wizard offers, in display order.
const List<String> muhuratWizardPurposes = [
  'marriage',
  'grihaPravesh',
  'business',
  'vehicle',
  'travel',
];

/// A screened day with its Tara for the person, when their birth star is
/// known.
class RankedMuhuratDay {
  final MuhuratCandidate candidate;
  final Tara? tara;

  const RankedMuhuratDay(this.candidate, this.tara);

  bool get goodForYou => tara?.strength == Strength.good;
  bool get badForYou => tara?.strength == Strength.bad;
}

/// Orders screened days for a person: days good for their birth star first,
/// then neutral ones, then days whose Tara is unfavourable; by date within
/// each group. Without a birth star the dates keep their order.
List<RankedMuhuratDay> rankMuhuratDays(
  List<MuhuratCandidate> candidates,
  int? birthNakshatra,
) {
  final ranked = [
    for (final c in candidates)
      RankedMuhuratDay(
        c,
        birthNakshatra == null
            ? null
            : switch (nakshatraIndexByName(c.panchang.nakshatra)) {
                final int index => Tara.of(birthNakshatra, index),
                null => null,
              },
      ),
  ];
  int group(RankedMuhuratDay d) => d.goodForYou
      ? 0
      : d.badForYou
      ? 2
      : 1;
  ranked.sort((a, b) {
    final byGroup = group(a).compareTo(group(b));
    return byGroup != 0
        ? byGroup
        : a.candidate.date.compareTo(b.candidate.date);
  });
  return ranked;
}

/// Index (0–26) of a Panchang nakshatra name, or null when unknown.
int? nakshatraIndexByName(String name) {
  final value = name.trim().toLowerCase();
  for (var i = 0; i < nakshatraNames.length; i++) {
    if (nakshatraNames[i].toLowerCase() == value) return i;
  }
  // Allow spelling variants such as "Dhanishta" by the longest prefix match.
  int? best;
  var bestLength = 0;
  for (var i = 0; i < nakshatraNames.length; i++) {
    final known = nakshatraNames[i].toLowerCase();
    final shared = _sharedPrefix(known, value);
    if (shared >= 5 && shared > bestLength) {
      best = i;
      bestLength = shared;
    }
  }
  return best;
}

int _sharedPrefix(String a, String b) {
  var i = 0;
  while (i < a.length && i < b.length && a[i] == b[i]) {
    i++;
  }
  return i;
}

/// "Find a muhurat" in three steps: what it is for, from when, and the best
/// days, ranked for the person's birth star.
class MuhuratWizardPage extends ConsumerStatefulWidget {
  const MuhuratWizardPage({super.key});

  @override
  ConsumerState<MuhuratWizardPage> createState() => _MuhuratWizardPageState();
}

class _MuhuratWizardPageState extends ConsumerState<MuhuratWizardPage> {
  int _step = 0;
  String? _purpose;
  DateTime _start = DateUtils.dateOnly(DateTime.now());
  bool _forMe = true;

  Future<List<RankedMuhuratDay>>? _results;

  void _search() {
    final place = ref.read(panchangPlaceProvider).value;
    final purpose = _purpose;
    if (place == null || purpose == null) return;
    final location = place.location;
    final service = MuhuratCandidateSearchService(
      ref.read(dailyPanchangRepositoryProvider),
    );
    final forMe = _forMe;
    setState(() {
      _step = 2;
      _results = () async {
        final candidates = await service.search(
          purpose: purpose,
          startDate: _start,
          latitude: location.latitude,
          longitude: location.longitude,
          timezone: location.timezone,
        );
        int? birthNakshatra;
        if (forMe) {
          final kundali = await ref.read(kundaliProvider.future);
          if (kundali != null) {
            birthNakshatra = nakshatraIndexOf(kundali.moonLongitude);
          }
        }
        return rankMuhuratDays(candidates, birthNakshatra);
      }();
    });
  }

  String _purposeLabel(String purpose) {
    final l10n = context.l10n;
    return switch (purpose) {
      'marriage' => l10n.muhuratPurposeMarriage,
      'grihaPravesh' => l10n.muhuratPurposeGrihaPravesh,
      'business' => l10n.muhuratPurposeBusiness,
      'vehicle' => l10n.muhuratPurposeVehicle,
      'travel' => l10n.muhuratPurposeTravel,
      _ => l10n.muhuratPurposeGeneral,
    };
  }

  static IconData _purposeIcon(String purpose) => switch (purpose) {
    'marriage' => Icons.favorite_outline,
    'grihaPravesh' => Icons.home_outlined,
    'business' => Icons.storefront_outlined,
    'vehicle' => Icons.directions_car_outlined,
    'travel' => Icons.flight_takeoff_outlined,
    _ => Icons.event_available_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = [
      l10n.muhuratWizardStepPurpose,
      l10n.muhuratWizardStepWhen,
      l10n.muhuratWizardStepResults,
    ];

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step -= 1);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.muhuratWizardTitle)),
        body: Column(
          children: [
            _StepBar(steps: steps, current: _step),
            Expanded(
              child: switch (_step) {
                0 => _purposeStep(),
                1 => _whenStep(),
                _ => _resultsStep(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _purposeStep() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          l10n.muhuratWizardPurposeQuestion,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        for (final purpose in muhuratWizardPurposes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: Icon(_purposeIcon(purpose), color: AppColors.primary),
                title: Text(_purposeLabel(purpose)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => setState(() {
                  _purpose = purpose;
                  _step = 1;
                }),
              ),
            ),
          ),
      ],
    );
  }

  Widget _whenStep() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final place = ref.watch(panchangPlaceProvider);
    final hasChart = ref.watch(kundaliProvider).value != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          l10n.muhuratWizardWhenQuestion(_purposeLabel(_purpose!)),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(l10n.muhuratWizardStartLabel),
            subtitle: Text(DateFormat.yMMMEd(locale).format(_start)),
            trailing: TextButton(
              onPressed: () async {
                final today = DateUtils.dateOnly(DateTime.now());
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _start,
                  firstDate: today,
                  lastDate: DateTime(today.year + 2, today.month, today.day),
                );
                if (picked != null) setState(() => _start = picked);
              },
              child: Text(l10n.muhuratWizardChange),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.muhuratWizardRangeNote(MuhuratCandidateSearchService.searchDays),
          style: theme.textTheme.bodySmall,
        ),
        if (hasChart) ...[
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              value: _forMe,
              onChanged: (value) => setState(() => _forMe = value),
              title: Text(l10n.muhuratWizardForMe),
              subtitle: Text(l10n.muhuratWizardForMeNote),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: place.value == null ? null : _search,
          icon: const Icon(Icons.search),
          label: Text(l10n.muhuratWizardFind),
        ),
        if (place.value?.isFallback ?? false) ...[
          const SizedBox(height: 8),
          PanchangPlaceNote(place: place.value!),
        ],
      ],
    );
  }

  Widget _resultsStep() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return FutureBuilder<List<RankedMuhuratDay>>(
      future: _results,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.muhuratCandidateSearching),
              ],
            ),
          );
        }
        final days = snapshot.data;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              l10n.muhuratWizardResultsTitle(_purposeLabel(_purpose!)),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.muhuratCandidateDisclaimer,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (snapshot.hasError)
              Text(l10n.muhuratCandidateSearchError)
            else if (days == null || days.isEmpty)
              Text(l10n.muhuratWizardNone)
            else
              for (final day in days) _DayTile(day: day),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step = 1),
                    child: Text(l10n.muhuratWizardChangeDates),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _step = 0;
                      _purpose = null;
                      _results = null;
                    }),
                    child: Text(l10n.muhuratWizardStartOver),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StepBar extends StatelessWidget {
  final List<String> steps;
  final int current;

  const _StepBar({required this.steps, required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= current
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${i + 1}. ${steps[i]}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: i == current
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: i == current ? FontWeight.w800 : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final RankedMuhuratDay day;

  const _DayTile({required this.day});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final panchang = day.candidate.panchang;
    final tara = day.tara;

    final (Color? chipColor, String? chipText) = switch (tara) {
      null => (null, null),
      _ when day.goodForYou => (
        AppColors.success,
        l10n.muhuratWizardGoodForYou(l10n.yourDayTaraName(tara.name)),
      ),
      _ when day.badForYou => (
        AppColors.error,
        l10n.muhuratWizardWeakForYou(l10n.yourDayTaraName(tara.name)),
      ),
      _ => (
        AppColors.textSecondary,
        l10n.horoscopeTaraChip(l10n.yourDayTaraName(tara.name)),
      ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat.yMMMEd(locale).format(day.candidate.date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (chipText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: chipColor!.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      chipText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: chipColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${l10n.homeTithi}: ${localizedTithi(l10n, panchang.tithi)}'
              '  ·  ${l10n.homeNakshatra}: '
              '${localizedNakshatra(l10n, panchang.nakshatra)}'
              '  ·  ${l10n.homeYoga}: ${localizedYoga(l10n, panchang.yoga)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
