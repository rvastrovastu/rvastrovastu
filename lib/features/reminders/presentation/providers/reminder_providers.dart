import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/localization/language_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../festivals/domain/entities/calendar_observance.dart';
import '../../../festivals/presentation/providers/festival_calendar_provider.dart';
import '../../../panchang/domain/entities/daily_panchang.dart';
import '../../../panchang/presentation/providers/daily_panchang_provider.dart';
import '../../../panchang/presentation/utils/panchang_localization.dart';
import '../../data/local_notification_service.dart';
import '../../data/reminder_settings_storage.dart';
import '../../domain/entities/reminder_settings.dart';
import '../../domain/usecases/plan_reminders.dart';

final reminderSettingsStorageProvider = Provider<ReminderSettingsStorage>(
  (ref) => const ReminderSettingsStorage(),
);

final reminderSettingsProvider =
    AsyncNotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
      ReminderSettingsNotifier.new,
    );

class ReminderSettingsNotifier extends AsyncNotifier<ReminderSettings> {
  @override
  Future<ReminderSettings> build() {
    return ref.read(reminderSettingsStorageProvider).load();
  }

  /// Saves [settings] and reschedules. When turning something on, asks for
  /// notification permission first; returns false if it was declined.
  Future<bool> update(ReminderSettings settings) async {
    final previous = state.value ?? const ReminderSettings();
    final turningOn = settings.anyEnabled && !previous.anyEnabled;

    var granted = true;
    if (turningOn) {
      try {
        granted = await LocalNotificationService.instance.requestPermission();
      } catch (error) {
        debugPrint('[REMINDERS] permission request failed: $error');
        granted = false;
      }
    }

    final saved = granted
        ? settings
        : const ReminderSettings(configured: true);

    await ref.read(reminderSettingsStorageProvider).save(saved);
    state = AsyncData(saved);
    await ref.read(reminderSchedulerProvider).sync();
    return granted;
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  ReminderScheduler.new,
);

/// Recomputes and schedules the next ~two weeks of reminders. Called on
/// app start, on resume and whenever settings change, so the rolling
/// window stays current without background work.
class ReminderScheduler {
  final Ref ref;
  bool _running = false;

  ReminderScheduler(this.ref);

  static const int morningDays = 14;

  Future<void> sync() async {
    if (_running) return;
    _running = true;
    try {
      await _sync();
    } catch (error, stack) {
      debugPrint('[REMINDERS] sync failed: $error');
      debugPrint('$stack');
    } finally {
      _running = false;
    }
  }

  Future<void> _sync() async {
    final settings = await ref.read(reminderSettingsStorageProvider).load();

    // Never touch the plugin before the user has made a choice.
    if (!settings.configured) return;

    final service = LocalNotificationService.instance;
    if (!settings.anyEnabled) {
      await service.cancelAll();
      return;
    }

    final place = await ref.read(festivalPlaceProvider.future);
    if (place == null) return;

    final location = tz.getLocation(place.timezone);
    final nowLocal = tz.TZDateTime.now(location);
    final now = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      nowLocal.hour,
      nowLocal.minute,
    );

    final panchangDays = <DailyPanchang>[];
    if (settings.morningEnabled) {
      final repository = ref.read(dailyPanchangRepositoryProvider);
      for (var i = 0; i < morningDays; i++) {
        panchangDays.add(
          await repository.calculate(
            date: DateTime(now.year, now.month, now.day + i),
            latitude: place.latitude,
            longitude: place.longitude,
            timezone: place.timezone,
          ),
        );
      }
    }

    var observances = const <CalendarObservance>[];
    try {
      observances =
          (await ref.read(festivalCalendarProvider.future))?.observances ??
          const [];
    } catch (error) {
      debugPrint('[REMINDERS] festival calendar unavailable: $error');
    }

    final plan = const PlanReminders()(
      settings: settings,
      now: now,
      panchangDays: panchangDays,
      observances: observances,
    );

    final l10n = lookupAppLocalizations(
      Locale(ref.read(languageProvider).code),
    );

    final requests = [
      for (final reminder in plan)
        _request(l10n, location, reminder),
    ];

    await service.replaceAll(requests);
    debugPrint('[REMINDERS] scheduled ${requests.length}');
  }

  NotificationRequest _request(
    AppLocalizations l10n,
    tz.Location location,
    PlannedReminder reminder,
  ) {
    final at = tz.TZDateTime(
      location,
      reminder.at.year,
      reminder.at.month,
      reminder.at.day,
      reminder.at.hour,
      reminder.at.minute,
    );

    switch (reminder.kind) {
      case ReminderKind.morning:
        final panchang = reminder.panchang!;
        final festival = reminder.observances.isEmpty
            ? null
            : l10n.festivalName(reminder.observances.first.name);
        return NotificationRequest(
          id: reminder.id,
          at: at,
          isDaily: true,
          title: festival == null
              ? l10n.reminderMorningTitle(localizedTithi(l10n, panchang.tithi))
              : l10n.reminderMorningFestivalTitle(festival),
          body: l10n.reminderMorningBody(
            localizedNakshatra(l10n, panchang.nakshatra),
            panchang.rahuKaal,
          ),
        );
      case ReminderKind.festivalEve:
      case ReminderKind.vratEve:
        return NotificationRequest(
          id: reminder.id,
          at: at,
          isDaily: false,
          title: l10n.reminderEveTitle(
            l10n.festivalName(reminder.observances.first.name),
          ),
          body: l10n.reminderEveBody,
        );
    }
  }
}
