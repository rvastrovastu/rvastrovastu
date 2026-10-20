import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../membership/domain/membership.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../membership/presentation/widgets/premium_gate.dart';

import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/domain/models/kundali_input.dart';
import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../../birth_profile/data/models/birth_profile_model.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../data/services/compatibility_pdf_service.dart';
import '../../domain/entities/compatibility_result.dart';
import '../../domain/usecases/calculate_ashtakoota.dart';
import '../../../dosha/domain/entities/manglik_result.dart';
import '../../../dosha/domain/usecases/check_manglik_dosha.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/koota_score.dart';

class CompatibilityPage extends ConsumerStatefulWidget {
  const CompatibilityPage({super.key});

  @override
  ConsumerState<CompatibilityPage> createState() => _CompatibilityPageState();
}

class _CompatibilityPageState extends ConsumerState<CompatibilityPage> {
  String? _brideId;
  String? _groomId;
  CompatibilityResult? _result;
  _ManglikComparison? _manglik;
  Kundali? _brideKundali;
  Kundali? _groomKundali;
  CompatibilityReportLanguage _reportLanguage =
      CompatibilityReportLanguage.english;
  String? _error;
  bool _calculating = false;
  int _calculationRequest = 0;

  /// [role] is `bride` or `groom`.
  String? _profileValidationError(BirthProfileModel profile, String role) {
    final l10n = AppLocalizations.of(context);
    final label = l10n.compatPerson(role);
    if (profile.birthTime.trim().isEmpty ||
        !RegExp(
          r'^(?:[01]\d|2[0-3]):[0-5]\d$',
        ).hasMatch(profile.birthTime.trim())) {
      return l10n.compatInvalidTime(label);
    }

    final location = profile.location;
    if (location.city.trim().isEmpty ||
        location.timezone.trim().isEmpty ||
        !location.latitude.isFinite ||
        !location.longitude.isFinite ||
        location.latitude < -90 ||
        location.latitude > 90 ||
        location.longitude < -180 ||
        location.longitude > 180 ||
        (location.latitude == 0 && location.longitude == 0)) {
      return l10n.compatInvalidLocation(label);
    }

    if (profile.dateOfBirth.isAfter(DateTime.now())) {
      return l10n.compatFutureDate(label);
    }

    return null;
  }

  Future<void> _calculate(List<BirthProfileModel> profiles) async {
    final l10n = AppLocalizations.of(context);
    if (profiles.length < 2) {
      setState(() {
        _calculationRequest++;
        _calculating = false;
        _result = null;
        _error = l10n.compatNeedTwoProfiles;
      });
      return;
    }

    final brideId = _brideId ?? profiles[0].id;
    final groomId = _groomId ?? profiles[1].id;

    if (brideId == groomId) {
      setState(() {
        _calculationRequest++;
        _calculating = false;
        _result = null;
        _error = l10n.compatSelectDifferent;
      });
      return;
    }

    final brideMatches = profiles.where((p) => p.id == brideId);
    final groomMatches = profiles.where((p) => p.id == groomId);

    if (brideMatches.isEmpty || groomMatches.isEmpty) {
      setState(() {
        _calculationRequest++;
        _calculating = false;
        _result = null;
        _error = l10n.compatProfileUnavailable;
      });
      return;
    }

    final bride = brideMatches.first;
    final groom = groomMatches.first;

    final brideError = _profileValidationError(bride, 'bride');
    final groomError = _profileValidationError(groom, 'groom');
    if (brideError != null || groomError != null) {
      setState(() {
        _calculationRequest++;
        _calculating = false;
        _result = null;
        _error = brideError ?? groomError;
      });
      return;
    }

    final requestId = ++_calculationRequest;
    setState(() {
      _calculating = true;
      _error = null;
      _result = null;
      _manglik = null;
      _brideKundali = null;
      _groomKundali = null;
    });

    try {
      final repository = ref.read(astrologyRepositoryProvider);
      final brideKundali = await repository.calculateKundali(_inputFor(bride));
      if (!mounted || requestId != _calculationRequest) return;

      final groomKundali = await repository.calculateKundali(_inputFor(groom));
      if (!mounted || requestId != _calculationRequest) return;

      final result = CalculateAshtakoota()(
        brideNakshatra: brideKundali.nakshatra,
        brideRashi: brideKundali.moonSign,
        groomNakshatra: groomKundali.nakshatra,
        groomRashi: groomKundali.moonSign,
      );

      // Manglik is supplementary: if a chart lacks the planets it needs,
      // still show the Ashtakoota result.
      _ManglikComparison? manglik;
      try {
        const checkManglik = CheckManglikDosha();
        manglik = _ManglikComparison(
          bride: checkManglik(brideKundali),
          groom: checkManglik(groomKundali),
        );
      } on ArgumentError {
        manglik = null;
      }

      if (!mounted || requestId != _calculationRequest) return;
      setState(() {
        _result = result;
        _manglik = manglik;
        _brideKundali = brideKundali;
        _groomKundali = groomKundali;
      });
    } catch (error) {
      if (!mounted || requestId != _calculationRequest) return;
      setState(() => _error = l10n.compatUnable('$error'));
    } finally {
      if (mounted && requestId == _calculationRequest) {
        setState(() => _calculating = false);
      }
    }
  }

  Future<void> _exportPdf(List<BirthProfileModel> profiles) async {
    if (!ref.read(canUseProvider(PremiumFeature.compatibilityPdf))) {
      await openPaywall(context, PremiumFeature.compatibilityPdf);
      return;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final result = _result;
    if (result == null || profiles.length < 2) return;

    final brideId = _brideId ?? profiles[0].id;
    final groomId = _groomId ?? profiles[1].id;
    final brideMatches = profiles.where((p) => p.id == brideId);
    final groomMatches = profiles.where((p) => p.id == groomId);

    if (brideMatches.isEmpty || groomMatches.isEmpty || brideId == groomId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.compatExportSelect)),
      );
      return;
    }

    try {
      CompatibilityReportPerson person(
        BirthProfileModel profile,
        Kundali? kundali,
        ManglikResult? manglik,
      ) => CompatibilityReportPerson(
        name: profile.name,
        dateOfBirth: profile.dateOfBirth,
        birthTime: profile.birthTime,
        place: profile.location.displayName,
        kundali: kundali,
        manglik: manglik,
      );

      final bytes = await const CompatibilityPdfService().buildReport(
        bride: person(brideMatches.first, _brideKundali, _manglik?.bride),
        groom: person(groomMatches.first, _groomKundali, _manglik?.groom),
        result: result,
        language: _reportLanguage,
      );

      if (!mounted) return;

      await Printing.layoutPdf(
        name: 'marriage_compatibility_report.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.compatPdfUnable)),
      );
    }
  }

  KundaliInput _inputFor(BirthProfileModel profile) {
    return KundaliInput(
      dateOfBirth: profile.dateOfBirth,
      birthTime: profile.birthTime,
      latitude: profile.location.latitude,
      longitude: profile.location.longitude,
      timezone: profile.location.timezone,
    );
  }

  String _formatScore(double score) {
    return score == score.roundToDouble()
        ? score.toStringAsFixed(0)
        : score.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(birthProfilesProvider);
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.compatTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.favorite_outline, size: 42),
            const SizedBox(height: 12),
            Text(
              l10n.compatHeading,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.compatIntro,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (profiles.length < 2) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    l10n.compatNeedTwoProfiles,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push('/saved-profiles'),
                icon: const Icon(Icons.people_outline),
                label: Text(l10n.compatManageProfiles),
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: profiles.any((p) => p.id == _brideId)
                    ? _brideId
                    : profiles[0].id,
                decoration: InputDecoration(
                  labelText: l10n.compatBrideProfile,
                  border: const OutlineInputBorder(),
                ),
                items: profiles
                    .map(
                      (profile) => DropdownMenuItem(
                        value: profile.id,
                        child: Text(
                          '${profile.name} (${profile.relationship})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _brideId = value;
                    _calculationRequest++;
                    _calculating = false;
                    _result = null;
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: profiles.any((p) => p.id == _groomId)
                    ? _groomId
                    : profiles[1].id,
                decoration: InputDecoration(
                  labelText: l10n.compatGroomProfile,
                  border: const OutlineInputBorder(),
                ),
                items: profiles
                    .map(
                      (profile) => DropdownMenuItem(
                        value: profile.id,
                        child: Text(
                          '${profile.name} (${profile.relationship})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _groomId = value;
                    _calculationRequest++;
                    _calculating = false;
                    _result = null;
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _calculating ? null : () => _calculate(profiles),
                icon: _calculating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calculate_outlined),
                label: Text(
                  _calculating ? l10n.compatCalculating : l10n.compatCalculate,
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: colors.error)),
            ],
            if (_result != null) ...[
              const SizedBox(height: 24),
              _CompatibilityResultView(
                result: _result!,
                formatScore: _formatScore,
                detailsLocked: !ref.watch(
                  canUseProvider(PremiumFeature.compatibilityDetails),
                ),
              ),
              if (_manglik != null &&
                  ref.watch(
                    canUseProvider(PremiumFeature.compatibilityDetails),
                  )) ...[
                const SizedBox(height: 16),
                _ManglikMatchCard(comparison: _manglik!),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<CompatibilityReportLanguage>(
                initialValue: _reportLanguage,
                decoration: InputDecoration(
                  labelText: l10n.compatPdfLanguage,
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: CompatibilityReportLanguage.english,
                    child: Text('English'),
                  ),
                  DropdownMenuItem(
                    value: CompatibilityReportLanguage.hindi,
                    child: Text('Hindi (हिन्दी)'),
                  ),
                  DropdownMenuItem(
                    value: CompatibilityReportLanguage.marathi,
                    child: Text('Marathi (मराठी)'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _reportLanguage = value);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _calculating ? null : () => _exportPdf(profiles),
                icon: Icon(
                  ref.watch(canUseProvider(PremiumFeature.compatibilityPdf))
                      ? Icons.picture_as_pdf_outlined
                      : Icons.lock_outline_rounded,
                ),
                label: Text(l10n.compatExportPdf),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              l10n.compatDisclaimer,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompatibilityResultView extends StatelessWidget {
  final CompatibilityResult result;
  final String Function(double) formatScore;

  /// Free users see the total score; the koota breakdown is Premium.
  final bool detailsLocked;

  const _CompatibilityResultView({
    required this.result,
    required this.formatScore,
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
