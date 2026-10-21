import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/vastu_localization.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/vastu_entry_assessment.dart';
import '../../domain/entities/vastu_entry_direction.dart';
import '../../domain/entities/vastu_entry_segment.dart';
import '../../domain/entities/vastu_entrance_input.dart';
import '../providers/vastu_entry_provider.dart';
import '../widgets/vastu_entrance_map.dart';

class VastuEntryAnalysisPage extends ConsumerStatefulWidget {
  const VastuEntryAnalysisPage({super.key});

  @override
  ConsumerState<VastuEntryAnalysisPage> createState() =>
      _VastuEntryAnalysisPageState();
}

class _VastuEntryAnalysisPageState
    extends ConsumerState<VastuEntryAnalysisPage> {
  VastuEntryDirection _selectedDirection = VastuEntryDirection.west;

  // W4 center = (4 - 0.5) / 8 = 0.4375.
  double _normalizedPosition = (VastuEntrySegment.w4.pada - 0.5) / 8.0;

  void _selectSegment(VastuEntrySegment segment) {
    setState(() {
      _selectedDirection = segment.direction;
      _normalizedPosition = (segment.pada - 0.5) / 8.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final calculator = ref.watch(calculateVastuEntrySegmentProvider);

    final calculatedSegment = calculator(
      VastuEntranceInput(
        direction: _selectedDirection,
        normalizedPosition: _normalizedPosition,
      ),
    );

    final supportedSegments = ref.watch(vastuSupportedEntrySegmentsProvider);
    final hasAssessment = supportedSegments.contains(calculatedSegment);

    final assessment = hasAssessment
        ? ref.watch(vastuEntryAssessmentProvider(calculatedSegment))
        : null;

    final deity = ref.watch(vastuEntryDeityProvider(calculatedSegment));

    return Scaffold(
      key: const Key('vastu-entry-analysis-page'),
      appBar: AppBar(title: Text(l10n.vastuEntranceAnalysis)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EntranceInputCard(
                direction: _selectedDirection,
                normalizedPosition: _normalizedPosition,
                calculatedSegment: calculatedSegment,
                l10n: l10n,
                onDirectionChanged: (direction) {
                  setState(() {
                    _selectedDirection = direction;
                  });
                },
                onPositionChanged: (position) {
                  setState(() {
                    _normalizedPosition = position;
                  });
                },
                onPadaSelected: _selectSegment,
              ),
              const SizedBox(height: 20),
              VastuEntranceMap(
                selectedSegment: calculatedSegment,
                onSegmentSelected: _selectSegment,
              ),
              const SizedBox(height: 20),
              _CalculatedPadaCard(segment: calculatedSegment, l10n: l10n),
              const SizedBox(height: 14),
              if (assessment != null)
                _AssessmentCard(
                  assessment: assessment,
                  deityKey: deity.deityKey,
                  l10n: l10n,
                )
              else
                _UnavailableAssessmentCard(
                  segment: calculatedSegment,
                  deityKey: deity.deityKey,
                  l10n: l10n,
                ),
              const SizedBox(height: 14),
              _EntranceResultCard(
                direction: localizedVastuDirection(
                  l10n,
                  calculatedSegment.direction,
                ),
                pada: calculatedSegment.code,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntranceInputCard extends StatelessWidget {
  const _EntranceInputCard({
    required this.direction,
    required this.normalizedPosition,
    required this.calculatedSegment,
    required this.l10n,
    required this.onDirectionChanged,
    required this.onPositionChanged,
    required this.onPadaSelected,
  });

  final VastuEntryDirection direction;
  final double normalizedPosition;
  final VastuEntrySegment calculatedSegment;
  final AppLocalizations l10n;
  final ValueChanged<VastuEntryDirection> onDirectionChanged;
  final ValueChanged<double> onPositionChanged;
  final ValueChanged<VastuEntrySegment> onPadaSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final positionPercent = normalizedPosition * 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.vastuEntranceDirection,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<VastuEntryDirection>(
            key: const Key('vastu-entry-direction'),
            initialValue: direction,
            decoration: InputDecoration(
              labelText: l10n.vastuSelectDirection,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            items: [
              for (final item in const [
                VastuEntryDirection.north,
                VastuEntryDirection.east,
                VastuEntryDirection.south,
                VastuEntryDirection.west,
              ])
                DropdownMenuItem<VastuEntryDirection>(
                  value: item,
                  child: Text(localizedVastuDirection(l10n, item)),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onDirectionChanged(value);
              }
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.vastuEntrancePosition,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                calculatedSegment.code,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${positionPercent.round()}%',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Slider(
            key: const Key('vastu-entry-position-slider'),
            value: normalizedPosition,
            min: 0,
            max: 1,
            divisions: 100,
            label: calculatedSegment.code,
            onChanged: onPositionChanged,
          ),
          const SizedBox(height: 2),
          _PadaScale(
            direction: direction,
            calculatedSegment: calculatedSegment,
            onPadaSelected: onPadaSelected,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.vastuPositionStart,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                l10n.vastuPositionEnd,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadaScale extends StatelessWidget {
  const _PadaScale({
    required this.direction,
    required this.calculatedSegment,
    required this.onPadaSelected,
  });

  final VastuEntryDirection direction;
  final VastuEntrySegment calculatedSegment;
  final ValueChanged<VastuEntrySegment> onPadaSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 1; i <= 8; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  final segment = VastuEntrySegment.values.firstWhere(
                    (candidate) =>
                        candidate.direction == direction &&
                        candidate.number == i,
                  );
                  onPadaSelected(segment);
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: calculatedSegment.number == i
                        ? colors.primaryContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: calculatedSegment.number == i
                          ? colors.primary
                          : colors.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Text(
                      _segmentCode(direction, i),
                      key: Key(
                        'vastu-pada-selector-${_segmentCode(direction, i)}',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: calculatedSegment.number == i
                            ? colors.onPrimaryContainer
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _segmentCode(VastuEntryDirection direction, int number) {
    final prefix = switch (direction) {
      VastuEntryDirection.north => 'N',
      VastuEntryDirection.east => 'E',
      VastuEntryDirection.south => 'S',
      VastuEntryDirection.west => 'W',
      VastuEntryDirection.northeast => 'NE',
      VastuEntryDirection.southeast => 'SE',
      VastuEntryDirection.southwest => 'SW',
      VastuEntryDirection.northwest => 'NW',
    };

    return '$prefix$number';
  }
}

class _CalculatedPadaCard extends StatelessWidget {
  const _CalculatedPadaCard({required this.segment, required this.l10n});

  final VastuEntrySegment segment;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calculate_outlined,
            color: colors.onPrimaryContainer,
            size: 30,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.vastuCalculatedPada,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  segment.code,
                  key: const Key('vastu-calculated-pada'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableAssessmentCard extends StatelessWidget {
  const _UnavailableAssessmentCard({
    required this.segment,
    required this.deityKey,
    required this.l10n,
  });

  final VastuEntrySegment segment;
  final String deityKey;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.code,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.vastuTraditionalAssessment,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  localizedVastuDeity(l10n, deityKey),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.vastuAssessmentUnavailable,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _localizedSummary(AppLocalizations l10n, String key) {
  switch (key) {
    case 'vastuW4Summary':
      return l10n.vastuW4Summary;
    case 'vastuW5Summary':
      return l10n.vastuW5Summary;
    default:
      throw ArgumentError('Unsupported Vastu summary localization key: $key');
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.assessment,
    required this.deityKey,
    required this.l10n,
  });

  final VastuEntryAssessment assessment;
  final String deityKey;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      key: const Key('vastu-assessment-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.vastuAssessment,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assessment.segment.code,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localizedVastuLevel(l10n, assessment.level),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.vastuTraditionalAssessment,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              localizedVastuDeity(l10n, deityKey),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _localizedSummary(l10n, assessment.summaryKey),
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _EntranceResultCard extends StatelessWidget {
  const _EntranceResultCard({required this.direction, required this.pada});

  final String direction;
  final String pada;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const Key('vastu-entrance-result'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.explore_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.vastuEntrancePada,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ResultValue(
                    label: context.l10n.vastuEntranceDirection,
                    value: direction,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ResultValue(
                    label: context.l10n.vastuCalculatedPada,
                    value: pada,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultValue extends StatelessWidget {
  const _ResultValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
