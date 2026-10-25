import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/location/device_time_zone.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/consultation.dart';
import 'consultation_providers.dart';

/// The user's consultation requests and their status.
class MyConsultationsPage extends ConsumerWidget {
  const MyConsultationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final async = ref.watch(myConsultationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.consultMyBookings)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/consult'),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.consultTitle),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myConsultationsProvider.future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [Text(l10n.consultFailed, textAlign: TextAlign.center)],
          ),
          data: (requests) => requests.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(32),
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.consultNoBookings,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _BookingCard(request: requests[i]),
                ),
        ),
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  final ConsultationRequest request;

  const _BookingCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final deviceZone = ref.watch(deviceTimeZoneProvider).value;
    tz.Location zone;
    try {
      zone = tz.getLocation(
        deviceZone ?? ConsultationConfig.consultantTimezone,
      );
    } catch (_) {
      zone = tz.getLocation(ConsultationConfig.consultantTimezone);
    }
    final local = tz.TZDateTime.from(request.slotStart, zone);
    final when =
        '${DateFormat.yMMMEd(l10n.localeName).format(local)} · '
        '${DateFormat.jm(l10n.localeName).format(local)}';
    final color = switch (request.status) {
      ConsultationStatus.requested => AppColors.accent,
      ConsultationStatus.confirmed => AppColors.success,
      ConsultationStatus.completed => AppColors.primary,
      ConsultationStatus.cancelled => AppColors.textMuted,
    };
    final canCancel =
        request.status == ConsultationStatus.requested &&
        request.id != null &&
        request.slotStart.isAfter(DateTime.now().toUtc());

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.consultTopic(request.topic.name),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                child: Text(
                  l10n.consultStatus(request.status.name),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(when, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(
            '${l10n.consultMinutes(request.minutes)} · '
            '${l10n.consultMode(request.mode.name)} · ${request.priceLabel}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (canCancel)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      content: Text(l10n.consultCancelConfirm),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(l10n.consultCancel),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    await ref
                        .read(consultationRepositoryProvider)
                        .cancel(request.id!);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.consultFailed)),
                      );
                    }
                  }
                  ref.invalidate(myConsultationsProvider);
                },
                child: Text(l10n.consultCancel),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}
