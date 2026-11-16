import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/consultation.dart';

/// Shows the four steps of a booking, what is done, and what happens next.
/// Steps: Requested → Confirmed → Paid → Called.
class ConsultationTimeline extends StatelessWidget {
  const ConsultationTimeline({
    super.key,
    required this.status,
    required this.slotStart,
    this.createdAt,
  });

  final ConsultationStatus status;
  final DateTime slotStart;
  final DateTime? createdAt;

  static int _stageOf(ConsultationStatus s) => switch (s) {
    ConsultationStatus.requested => 0,
    ConsultationStatus.confirmed => 1,
    ConsultationStatus.paid => 2,
    ConsultationStatus.completed => 3,
    ConsultationStatus.cancelled => -1,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.MMMd(locale).add_jm();

    if (status == ConsultationStatus.cancelled) {
      return Text(
        l10n.consultStatus(status.name),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final current = _stageOf(status);
    final completed = status == ConsultationStatus.completed;

    final steps = <_Step>[
      _Step(
        label: l10n.timelineRequested,
        at: createdAt,
        hint: l10n.timelineHintRequested,
      ),
      _Step(label: l10n.timelineConfirmed, hint: l10n.timelineHintConfirmed),
      _Step(label: l10n.timelinePaid, hint: l10n.timelineHintPaid),
      _Step(
        label: l10n.timelineCalled,
        at: completed ? slotStart : null,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            label: steps[i].label,
            at: steps[i].at == null
                ? null
                : dateFormat.format(steps[i].at!.toLocal()),
            done: i < current || (completed && i == current),
            current: !completed && i == current,
            // The hint tells the customer what happens next.
            hint: !completed && i == current ? steps[i].hint : null,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _Step {
  const _Step({required this.label, this.at, this.hint});

  final String label;
  final DateTime? at;
  final String? hint;
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.current,
    required this.isLast,
    this.at,
    this.hint,
  });

  final String label;
  final String? at;
  final String? hint;
  final bool done;
  final bool current;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active = done || current;
    final lineColor = done ? AppColors.primary : colors.onSurfaceVariant.withValues(alpha: 0.4);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : current
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: active ? AppColors.primary : lineColor,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: lineColor),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? colors.onSurface : colors.onSurfaceVariant,
                    ),
                  ),
                  if (at != null)
                    Text(
                      at!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        hint!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
