// lib/features/numerology/presentation/widgets/numerology_extras.dart
//
// Lo Shu grid and partner compatibility cards for the Numerology page.
// All visible text is translated via ExtraStr.

import 'package:flutter/material.dart';

import '../../domain/numerology.dart';
import '../../domain/numerology_forecast.dart';
import 'lo_shu_guide.dart';
import 'numerology_extra_strings.dart';

/// Lo Shu grid built from the birth date digits.
class LoShuCard extends StatelessWidget {
  const LoShuCard({super.key, required this.dateOfBirth});

  final DateTime dateOfBirth;

  static const _grid = [
    [4, 9, 2],
    [3, 5, 7],
    [8, 1, 6],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = NumerologyForecast.loShuCounts(dateOfBirth);
    final missing = [
      for (final e in counts.entries)
        if (e.value == 0) e.key,
    ]..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ExtraStr.of(context, 'loShu'), style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              ExtraStr.of(context, 'loShuDesc'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final row in _grid)
              Row(
                children: [
                  for (final n in row)
                    Expanded(
                      child: Container(
                        height: 64,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: counts[n]! > 0
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$n',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              counts[n]! > 0 ? '× ${counts[n]}' : '—',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Text(
              missing.isEmpty
                  ? ExtraStr.of(context, 'loShuComplete')
                  : ExtraStr.of(context, 'loShuMissing', {
                      'n': missing.join(', '),
                    }),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            LoShuPlanes(counts: counts),
          ],
        ),
      ),
    );
  }
}

/// Compares the user's birth number with a partner's birth day.
class CompatibilityCard extends StatefulWidget {
  const CompatibilityCard({super.key, required this.myMulank});

  final int myMulank;

  @override
  State<CompatibilityCard> createState() => _CompatibilityCardState();
}

class _CompatibilityCardState extends State<CompatibilityCard> {
  DateTime? _partner;

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _partner = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partner = _partner;

    String? text;
    if (partner != null) {
      final rel = NumerologyForecast.relation(
        widget.myMulank,
        Numerology.reduce(partner.day),
      );
      text = switch (rel) {
        NumberRelation.same => ExtraStr.of(context, 'cSame'),
        NumberRelation.friend => ExtraStr.of(context, 'cFriend'),
        NumberRelation.neutral => ExtraStr.of(context, 'cNeutral'),
        NumberRelation.challenging => ExtraStr.of(context, 'cChall'),
      };
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ExtraStr.of(context, 'compat'), style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              ExtraStr.of(context, 'compatDesc'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.favorite_border),
              label: Text(
                partner == null
                    ? ExtraStr.of(context, 'pickPartner')
                    : ExtraStr.of(context, 'partnerBorn', {
                        'd': '${partner.day}/${partner.month}/${partner.year}',
                      }),
              ),
            ),
            if (text != null) ...[
              const SizedBox(height: 12),
              Text(text, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
