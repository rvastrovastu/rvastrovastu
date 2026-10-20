import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../domain/entities/daily_panchang.dart';
import '../../domain/entities/daily_panchang_input.dart';
import '../../domain/entities/day_divisions.dart';
import '../providers/day_divisions_provider.dart';
import '../utils/panchang_share.dart';

/// Shares the day's Panchang as text. [iconOnly] suits an app bar.
class SharePanchangButton extends ConsumerWidget {
  final DailyPanchang panchang;
  final DailyPanchangInput input;
  final String? place;
  final bool iconOnly;

  const SharePanchangButton({
    super.key,
    required this.panchang,
    required this.input,
    this.place,
    this.iconOnly = false,
  });

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);

    DayDivisions? divisions;
    try {
      divisions = (await ref.read(dayDivisionsProvider(input).future)).today;
    } catch (_) {
      divisions = null;
    }
    if (!context.mounted) return;

    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatFullDate(input.date);
    final text = buildPanchangShareText(
      l10n: l10n,
      panchang: panchang,
      dateLabel: dateLabel,
      formatTime: localTimeFormatter(context, input.timezone),
      place: place,
      divisions: divisions,
    );

    try {
      await shareText(
        context,
        text: text,
        subject: l10n.panchangShareHeading(dateLabel),
      );
    } catch (_) {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Builder(
      builder: (buttonContext) => iconOnly
          ? IconButton(
              tooltip: l10n.shareAction,
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => _share(buttonContext, ref),
            )
          : TextButton.icon(
              onPressed: () => _share(buttonContext, ref),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(l10n.shareAction),
            ),
    );
  }
}
