import 'package:flutter/material.dart';

class NakshatraCard extends StatelessWidget {
  final String nakshatra;
  final int pada;
  final String moonSign;

  const NakshatraCard({
    super.key,
    required this.nakshatra,
    required this.pada,
    required this.moonSign,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Birth Nakshatra',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            nakshatra,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text('Pada $pada • Moon in $moonSign'),
        ],
      ),
    );
  }
}
