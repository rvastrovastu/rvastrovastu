// lib/features/numerology/presentation/widgets/lo_shu_guide.dart
//
// Reading guide for the Lo Shu grid: the three planes, what each one says
// about you, and how to use the result. Text comes from
// numerology_reading_strings.dart so it follows the selected language.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'numerology_reading_strings.dart';

class LoShuPlane {
  const LoShuPlane(this.key, this.numbers);

  /// Looks up the plane's name ('pn' + key) and meaning ('pm' + key).
  final String key;
  final List<int> numbers;
}

abstract final class LoShuGuide {
  /// The grid's rows, columns and diagonals used in common readings.
  static const planes = [
    LoShuPlane('Mental', [4, 9, 2]),
    LoShuPlane('Emotional', [3, 5, 7]),
    LoShuPlane('Practical', [8, 1, 6]),
    LoShuPlane('Action', [4, 3, 8]),
    LoShuPlane('Intuition', [9, 5, 1]),
    LoShuPlane('Purpose', [2, 7, 6]),
  ];
}

/// Shows how strong each plane of the grid is, with the digits that are missing.
class LoShuPlanes extends StatelessWidget {
  const LoShuPlanes({super.key, required this.counts});

  /// How often each digit 1–9 appears in the birth date.
  final Map<int, int> counts;

  static String _strength(BuildContext context, int present) => switch (present) {
        3 => ReadStr.of(context, 'sStrong'),
        2 => ReadStr.of(context, 'sGood'),
        1 => ReadStr.of(context, 'sDeveloping'),
        _ => ReadStr.of(context, 'sNeeds'),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ReadStr.of(context, 'loTitle'),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          ReadStr.of(context, 'loIntro'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final plane in LoShuGuide.planes) ...[
          _PlaneRow(plane: plane, counts: counts),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        Text(
          ReadStr.of(context, 'loWhat'),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (final key in const ['loB1', 'loB2', 'loB3', 'loB4'])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '•  ${ReadStr.of(context, key)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _PlaneRow extends StatelessWidget {
  const _PlaneRow({required this.plane, required this.counts});

  final LoShuPlane plane;
  final Map<int, int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final present = plane.numbers.where((n) => (counts[n] ?? 0) > 0).length;
    final missing = plane.numbers.where((n) => (counts[n] ?? 0) == 0).toList();
    final color = present == 3
        ? const Color(0xFF6FCF97)
        : present == 0
            ? AppColors.error
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${ReadStr.of(context, 'pn${plane.key}')}  (${plane.numbers.join(' · ')})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                child: Text(
                  LoShuPlanes._strength(context, present),
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ReadStr.of(context, 'pm${plane.key}'),
            style: theme.textTheme.bodySmall,
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ReadStr.of(context, 'loMissing', {
                'n': missing.join(', '),
                'm': missing
                    .map((n) => ReadStr.of(context, 'n$n'))
                    .join('; '),
              }),
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.accent),
            ),
          ],
        ],
      ),
    );
  }
}
