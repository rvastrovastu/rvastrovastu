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
    );

    await storage.save(saved);
    expect(await storage.load(), saved);
  });
}
