import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/reminder_settings.dart';

class ReminderSettingsStorage {
  static const _configured = 'reminders_configured';
  static const _morning = 'reminders_morning';
  static const _hour = 'reminders_morning_hour';
  static const _minute = 'reminders_morning_minute';
  static const _festivals = 'reminders_festivals';
  static const _vrats = 'reminders_vrats';
  static const _transits = 'reminders_transits';

  const ReminderSettingsStorage();

  Future<ReminderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = ReminderSettings();
    return ReminderSettings(
      configured: prefs.getBool(_configured) ?? defaults.configured,
      morningEnabled: prefs.getBool(_morning) ?? defaults.morningEnabled,
      morningHour: prefs.getInt(_hour) ?? defaults.morningHour,
      morningMinute: prefs.getInt(_minute) ?? defaults.morningMinute,
      festivalsEnabled: prefs.getBool(_festivals) ?? defaults.festivalsEnabled,
      vratsEnabled: prefs.getBool(_vrats) ?? defaults.vratsEnabled,
      transitsEnabled: prefs.getBool(_transits) ?? defaults.transitsEnabled,
    );
  }

  Future<void> save(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_configured, settings.configured);
    await prefs.setBool(_morning, settings.morningEnabled);
    await prefs.setInt(_hour, settings.morningHour);
    await prefs.setInt(_minute, settings.morningMinute);
    await prefs.setBool(_festivals, settings.festivalsEnabled);
    await prefs.setBool(_vrats, settings.vratsEnabled);
    await prefs.setBool(_transits, settings.transitsEnabled);
  }
}
