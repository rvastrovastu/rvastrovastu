import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/reminders/data/reminder_settings_storage.dart';
import 'package:rv_astro_vastu/features/reminders/domain/entities/reminder_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to unconfigured with everything off', () async {
    final settings = await const ReminderSettingsStorage().load();
    expect(settings, const ReminderSettings());
    expect(settings.configured, isFalse);
    expect(settings.anyEnabled, isFalse);
  });

  test('saves and loads every field', () async {
    const storage = ReminderSettingsStorage();
    const saved = ReminderSettings(
      configured: true,
      morningEnabled: true,
      morningHour: 6,
      morningMinute: 15,
      festivalsEnabled: false,
      vratsEnabled: true,
      transitsEnabled: true,
      checkInEnabled: true,
    );

    await storage.save(saved);
    expect(await storage.load(), saved);
  });

  test('moves the old 7:00 default to 8:00 once, keeping picked times', () async {
    SharedPreferences.setMockInitialValues({
      'reminders_configured': true,
      'reminders_morning': true,
      'reminders_morning_hour': 7,
      'reminders_morning_minute': 0,
    });
    const storage = ReminderSettingsStorage();
    expect((await storage.load()).morningHour, 8);

    // A 7:00 the user picks afterwards is kept.
    await storage.save(
      const ReminderSettings(configured: true, morningEnabled: true),
    );
    await storage.save(
      (await storage.load()).copyWith(morningHour: 7, morningMinute: 0),
    );
    expect((await storage.load()).morningHour, 7);
  });

  test('a picked time other than 7:00 is never moved', () async {
    SharedPreferences.setMockInitialValues({
      'reminders_morning_hour': 6,
      'reminders_morning_minute': 30,
    });
    final settings = await const ReminderSettingsStorage().load();
    expect(settings.morningHour, 6);
    expect(settings.morningMinute, 30);
  });
}
