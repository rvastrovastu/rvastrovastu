// lib/features/numerology/presentation/widgets/numerology_today_section.dart
//
// Numerology block for the Today page, styled with the app's celestial palette.
// All visible text is translated: labels via NumStr, dates via the device locale.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/numerology.dart';
import '../../domain/numerology_forecast.dart';
import 'numerology_strings.dart';
import 'numerology_reading_strings.dart';

class NumerologySection extends StatelessWidget {
  const NumerologySection({super.key, required this.birthDate, this.onDate});

  /// The user's date of birth.
  final DateTime birthDate;

  /// Date to read for. Defaults to now.
  final DateTime? onDate;

  static String _relationLabel(BuildContext context, NumberRelation r) =>
      switch (r) {
        NumberRelation.same => NumStr.of(context, 'strong'),
        NumberRelation.friend => NumStr.of(context, 'friendly'),
        NumberRelation.neutral => NumStr.of(context, 'neutral'),
        NumberRelation.challenging => NumStr.of(context, 'challenging'),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = onDate ?? DateTime.now();

    final report = const Numerology()(
      dateOfBirth: birthDate,
      name: '',
      year: now.year,
    );
    final mulank = report.mulank;
    final py = report.personalYear;
    final pm = NumerologyForecast.personalMonth(py, now.month);
    final pd = NumerologyForecast.personalDay(pm, now.day);
    final lucky = {pd, mulank}.toList()..sort();
    final dates = NumerologyForecast.luckyDates(mulank: mulank, from: now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero card: today's personal numbers
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.surfaceLight, Color(0xFF2F3478)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      NumStr.of(context, 'today'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat.yMMMMd(locale).format(now),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _NumberTile(
                      label: NumStr.of(context, 'day'),
                      value: pd,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NumberTile(
                      label: NumStr.of(context, 'month'),
                      value: pm,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NumberTile(
                      label: NumStr.of(context, 'year'),
                      value: py,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _HowToRead(
                title: ReadStr.of(context, 'readingTitle'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _ReadingLine(
                      label: ReadStr.of(context, 'yearHint'),
                      number: py,
                      meaning: ReadStr.year(context, py),
                    ),
                    Divider(height: 18, color: AppColors.outline),
                    _ReadingLine(
                      label: ReadStr.of(context, 'monthHint'),
                      number: pm,
                      meaning: ReadStr.month(context, pm),
                    ),
                    Divider(height: 18, color: AppColors.outline),
                    _ReadingLine(
                      label: ReadStr.of(context, 'dayHint'),
                      number: pd,
                      meaning: ReadStr.day(context, pd),
                    ),
                    const SizedBox(height: 14),
                    _AlignmentChip(
                      text: ReadStr.alignment(
                        context,
                        NumerologyForecast.relation(mulank, pd),
                        mulank,
                      ),
                      relation: NumerologyForecast.relation(mulank, pd),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Lucky numbers and colour
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      NumStr.of(context, 'luckyNumbers'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final n in lucky) ...[
                          _NumberOrb(number: n),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Strip(
                icon: Icons.palette_outlined,
                title: NumStr.of(context, 'luckyColour'),
                value: l10n.numerologyLuckyColour('n$mulank'),
                valueColor: _colourFor(mulank),
              ),
            ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Lucky dates
        Text(
          NumStr.of(context, 'luckyDates'),
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (dates.isEmpty)
          Text(
            NumStr.of(context, 'noLuckyDates'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dates.length,
              separatorBuilder: (context, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final (day, rel) = dates[i];
                return Container(
                  width: 124,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat.MMMd(locale).format(day),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        DateFormat.E(locale).format(day),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _relationLabel(context, rel),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: rel == NumberRelation.challenging
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.push('/numerology'),
          icon: const Icon(Icons.arrow_forward),
          label: Text(NumStr.of(context, 'seeFull')),
        ),
      ],
    );
  }
}

/// Colour each Mulank's lucky colour is written in, so the name matches its colour.
const Map<int, Color> _mulankColours = {
  1: Color(0xFFE5484D), // red
  2: Color(0xFFF5EBD7), // cream
  3: Color(0xFFF2D03B), // yellow
  4: Color(0xFF6C9BE8), // blue
  5: Color(0xFF8BD17C), // light green
  6: Color(0xFFF29AB8), // pink
  7: Color(0xFFA67CF0), // violet
  8: Color(0xFF7D86C8), // dark blue, lightened for dark backgrounds
  9: Color(0xFFC4577A), // maroon/berry
  11: Color(0xFFC0C0C8), // silver
  22: Color(0xFFF4EFE2), // ivory
  33: Color(0xFFF0B43C), // gold
};

Color _colourFor(int mulank) => _mulankColours[mulank] ?? AppColors.textPrimary;

/// A gold circle showing one lucky number.
class _NumberOrb extends StatelessWidget {
  const _NumberOrb({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          color: AppColors.onPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
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

/// A big number tile for Day, Month or Year.
class _NumberTile extends StatelessWidget {
  const _NumberTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.displaySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of the "How to read today" card: a number badge, its label and meaning.
class _ReadingLine extends StatelessWidget {
  const _ReadingLine({
    required this.label,
    required this.number,
    required this.meaning,
  });

  final String label;
  final int number;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          child: Text(
            '$number',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meaning,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Coloured pill showing how today compares with the birth number.
class _AlignmentChip extends StatelessWidget {
  const _AlignmentChip({required this.text, required this.relation});

  final String text;
  final NumberRelation relation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (relation) {
      NumberRelation.same || NumberRelation.friend => const Color(0xFF6FCF97),
      NumberRelation.neutral => AppColors.textSecondary,
      NumberRelation.challenging => AppColors.error,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// A tappable "How to read today" link. The reading stays hidden until
/// tapped, so the numbers above take the space they need.
class _HowToRead extends StatefulWidget {
  const _HowToRead({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  State<_HowToRead> createState() => _HowToReadState();
}

class _HowToReadState extends State<_HowToRead> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _open ? widget.child : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
