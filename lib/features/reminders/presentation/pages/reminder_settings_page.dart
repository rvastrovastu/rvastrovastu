import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/reminder_settings.dart';
import '../providers/reminder_providers.dart';

class ReminderSettingsPage extends ConsumerWidget {
  const ReminderSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(reminderSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.remindersTitle)),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (settings) => _SettingsList(settings: settings),
      ),
    );
  }
}

class _SettingsList extends ConsumerWidget {
  final ReminderSettings settings;

  const _SettingsList({required this.settings});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    ReminderSettings next,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final granted = await ref
        .read(reminderSettingsProvider.notifier)
        .save(next.copyWith(configured: true));
    if (!granted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.remindersPermissionDenied)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final time = TimeOfDay(
      hour: settings.morningHour,
      minute: settings.morningMinute,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(l10n.remindersIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.wb_twilight_outlined),
                title: Text(l10n.remindersMorningTitle),
                subtitle: Text(l10n.remindersMorningSubtitle),
                value: settings.morningEnabled,
                onChanged: (value) => _save(
                  context,
                  ref,
                  settings.copyWith(morningEnabled: value),
                ),
              ),
              ListTile(
                enabled: settings.morningEnabled,
                leading: const Icon(Icons.schedule),
                title: Text(l10n.remindersMorningTime),
                trailing: Text(
                  time.format(context),
                  style: theme.textTheme.titleMedium,
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: time,
                  );
                  if (picked == null || !context.mounted) return;
                  await _save(
                    context,
                    ref,
                    settings.copyWith(
                      morningHour: picked.hour,
                      morningMinute: picked.minute,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.celebration_outlined),
                title: Text(l10n.remindersFestivalsTitle),
                subtitle: Text(l10n.remindersFestivalsSubtitle),
                value: settings.festivalsEnabled,
                onChanged: (value) => _save(
                  context,
                  ref,
                  settings.copyWith(festivalsEnabled: value),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.spa_outlined),
                title: Text(l10n.remindersVratsTitle),
                subtitle: Text(l10n.remindersVratsSubtitle),
                value: settings.vratsEnabled,
                onChanged: (value) => _save(
                  context,
                  ref,
                  settings.copyWith(vratsEnabled: value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.remindersFootnote, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
