import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/reminder_settings.dart';
import '../providers/reminder_providers.dart';

/// One-time invitation on Today to turn reminders on. Hidden once the user
/// has chosen either way (choices live in Reminder settings afterwards).
class ReminderPromptCard extends ConsumerWidget {
  const ReminderPromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(reminderSettingsProvider).value;
    if (settings == null || settings.configured) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final notifier = ref.read(reminderSettingsProvider.notifier);

    // A slim banner: icon, one line of why, and the two choices.
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.remindersPromptTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.remindersPromptBody,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Side by side when they fit; stacked (primary on top) on
          // narrow phones or with long translations.
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 4,
            overflowSpacing: 2,
            overflowAlignment: OverflowBarAlignment.end,
            overflowDirection: VerticalDirection.up,
            children: [
              TextButton(
                onPressed: () =>
                    notifier.save(const ReminderSettings(configured: true)),
                child: Text(l10n.remindersNotNow),
              ),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final granted = await notifier.save(
                    ReminderSettings.recommended,
                  );
                  if (!granted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.remindersPermissionDenied)),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: Text(l10n.remindersTurnOn),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
