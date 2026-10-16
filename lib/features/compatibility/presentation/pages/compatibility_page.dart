import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../astrology/domain/models/kundali_input.dart';
import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../../birth_profile/data/models/birth_profile_model.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../data/services/compatibility_pdf_service.dart';
import '../../domain/entities/compatibility_result.dart';
import '../../domain/usecases/calculate_ashtakoota.dart';
import '../../../dosha/domain/entities/manglik_result.dart';
import '../../../dosha/domain/usecases/check_manglik_dosha.dart';

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
  CompatibilityReportLanguage _reportLanguage =
      CompatibilityReportLanguage.english;
  String? _error;
  bool _calculating = false;
  int _calculationRequest = 0;

  String? _profileValidationError(BirthProfileModel profile, String label) {
    if (profile.birthTime.trim().isEmpty ||
        !RegExp(
          r'^(?:[01]\d|2[0-3]):[0-5]\d$',
        ).hasMatch(profile.birthTime.trim())) {
      return '$label profile has an invalid birth time. '
          'Edit the saved profile and enter time as HH:mm (24-hour).';
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
      return '$label profile has incomplete or invalid birth-location '
          'details. Edit the saved profile and verify its city, coordinates, '
          'and timezone.';
    }

    if (profile.dateOfBirth.isAfter(DateTime.now())) {
      return '$label profile has a birth date in the future. '
          'Please correct the saved profile.';
    }

    return null;
  }

  Future<void> _calculate(List<BirthProfileModel> profiles) async {
    if (profiles.length < 2) {
      setState(() {
        _calculationRequest++;
        _calculating = false;
        _result = null;
        _error =
            'Please save at least two birth profiles before '
            'calculating compatibility.';
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
        _error = 'Please select two different profiles.';
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
        _error =
            'A selected profile is no longer available. '
            'Please select both profiles again.';
      });
      return;
    }

    final bride = brideMatches.first;
    final groom = groomMatches.first;

    final brideError = _profileValidationError(bride, 'Bride');
    final groomError = _profileValidationError(groom, 'Groom');
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
      });
    } catch (error) {
      if (!mounted || requestId != _calculationRequest) return;
      setState(() => _error = 'Unable to calculate compatibility: $error');
    } finally {
      if (mounted && requestId == _calculationRequest) {
        setState(() => _calculating = false);
      }
    }
  }

  Future<void> _exportPdf(List<BirthProfileModel> profiles) async {
    final result = _result;
    if (result == null || profiles.length < 2) return;

    final brideId = _brideId ?? profiles[0].id;
    final groomId = _groomId ?? profiles[1].id;
    final brideMatches = profiles.where((p) => p.id == brideId);
    final groomMatches = profiles.where((p) => p.id == groomId);

    if (brideMatches.isEmpty || groomMatches.isEmpty || brideId == groomId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select two available, different profiles before exporting.',
          ),
        ),
      );
      return;
    }

    try {
      final bytes = await const CompatibilityPdfService().buildReport(
        brideName: brideMatches.first.name,
        groomName: groomMatches.first.name,
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
        const SnackBar(
          content: Text(
            'Unable to create the compatibility PDF. Please try again.',
          ),
        ),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Marriage Compatibility')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.favorite_outline, size: 42),
            const SizedBox(height: 12),
            Text(
              'Ashtakoota Guna Milan',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Compare two saved birth profiles using their Moon signs '
              'and Nakshatras.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (profiles.length < 2) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Please save at least two birth profiles before '
                    'calculating compatibility.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push('/saved-profiles'),
                icon: const Icon(Icons.people_outline),
                label: const Text('Manage Birth Profiles'),
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: profiles.any((p) => p.id == _brideId)
                    ? _brideId
                    : profiles[0].id,
                decoration: const InputDecoration(
                  labelText: 'Bride profile',
                  border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Groom profile',
                  border: OutlineInputBorder(),
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
                  _calculating
                      ? 'Calculating charts…'
                      : 'Calculate Compatibility',
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
              ),
              if (_manglik != null) ...[
                const SizedBox(height: 16),
                _ManglikMatchCard(comparison: _manglik!),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<CompatibilityReportLanguage>(
                initialValue: _reportLanguage,
                decoration: const InputDecoration(
                  labelText: 'PDF language',
                  border: OutlineInputBorder(),
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
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _reportLanguage = value);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _calculating ? null : () => _exportPdf(profiles),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF (Print or Save)'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Traditional astrology interpretation only. This score is '
              'not a scientifically validated prediction of relationship '
              'quality or success. Consult a qualified practitioner for '
              'tradition-specific interpretations and exceptions.',
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

  const _CompatibilityResultView({
    required this.result,
    required this.formatScore,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                const Text('Ashtakoota score'),
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
                      ? 'Meets the traditional 18-point threshold'
                      : 'Below the traditional 18-point threshold',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Eight Kootas', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (rankedKootas.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Relative score insights',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'These compare points earned within each Koota. '
                    'They are descriptive summaries, not relationship '
                    'predictions.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _KootaInsightRow(
                    label: 'Highest relative score',
                    name: 'Best relative percentage',
                    percentage: rankedKootas.first.percentage,
                  ),
                  if (rankedKootas.length > 1) ...[
                    const SizedBox(height: 10),
                    _KootaInsightRow(
                      label: 'Lowest relative score',
                      name: 'Lowest relative percentage',
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
                          koota.name,
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
                  Text(koota.explanation),
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
            'Traditional flags to review',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...result.traditionalFlags.map(
            (flag) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(flag),
            ),
          ),
          Text(
            'Flags are not a final verdict. Interpretations, exceptions, '
            'and remedies vary by tradition.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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

  static String _label(ManglikResult result) {
    switch (result.status) {
      case ManglikStatus.none:
        return 'Not Manglik';
      case ManglikStatus.mild:
        return 'Mild Manglik (from Moon/Venus)';
      case ManglikStatus.present:
        return 'Manglik';
      case ManglikStatus.cancelled:
        return 'Manglik placement, cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (String summary, IconData icon, Color color) =
        switch (comparison.match) {
          ManglikMatch.neitherManglik => (
            'Neither chart has an active Manglik dosha.',
            Icons.check_circle_outline,
            colors.primary,
          ),
          ManglikMatch.bothManglik => (
            'Both charts are Manglik, which is traditionally considered '
                'to balance out.',
            Icons.balance,
            colors.primary,
          ),
          ManglikMatch.onlyOneManglik => (
            'Only one chart is Manglik. Traditional matching reviews this '
                'further, together with cancellations and the full charts.',
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
                Text('Manglik check', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(summary),
            const SizedBox(height: 10),
            Text('Bride: ${_label(comparison.bride)}'),
            Text('Groom: ${_label(comparison.groom)}'),
          ],
        ),
      ),
    );
  }
}
