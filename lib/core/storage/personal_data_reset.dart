import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Removes personal data kept on this device when someone signs out or
/// deletes their account: birth profiles, Vastu plans, and daily check-ins.
/// Device settings (language, chart style, reminders, AI consent) are kept.
Future<void> clearPersonalDeviceData() async {
  final preferences = await SharedPreferences.getInstance();
  const personalKeys = [
    'birth_profile',
    'birth_profiles',
    'active_birth_profile_id',
    'vastu_layouts',
    'vastu_report_assignments',
    'daily_loop_remedy_days',
    'daily_loop_check_ins',
  ];
  for (final key in personalKeys) {
    await preferences.remove(key);
  }
  try {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/vastu_plans');
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {
    // Plan images are removed on a best-effort basis.
  }
}
