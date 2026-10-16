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

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.remindersPromptTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.remindersPromptBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => notifier.update(
                    const ReminderSettings(configured: true),
                  ),
                  child: Text(l10n.remindersNotNow),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final granted = await notifier.update(
                      ReminderSettings.recommended,
                    );
                    if (!granted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.remindersPermissionDenied),
                        ),
                      );
                    }
                  },
                  child: Text(l10n.remindersTurnOn),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
