import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Grey placeholder bars in the shape of the content that is on its way,
/// shown instead of a spinner so the page doesn't jump when it arrives.
/// Screen readers hear "Loading…".
///
/// The bars don't animate, so pages and tests that wait for animations to
/// settle are not held up.
class SkeletonLines extends StatelessWidget {
  /// Number of text lines below the title bar.
  final int lines;

  /// Whether to start with a shorter, taller title bar.
  final bool title;

  const SkeletonLines({super.key, this.lines = 3, this.title = true});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.textMuted.withValues(alpha: 0.16);

    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );

    // Last line shorter, like the end of a paragraph.
    final widths = [0.95, 0.88, 0.92, 0.8, 0.9];

    return Semantics(
      label:
          Localizations.of<AppLocalizations>(
            context,
            AppLocalizations,
          )?.loading ??
          'Loading…',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title) ...[bar(0.45, 18), const SizedBox(height: 14)],
            for (var i = 0; i < lines; i++) ...[
              bar(i == lines - 1 ? 0.6 : widths[i % widths.length], 12),
              if (i < lines - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
