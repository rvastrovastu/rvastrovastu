import 'package:timezone/timezone.dart' as tz;

import '../../astrology/domain/entities/kundali.dart';
import '../../birth_profile/data/models/birth_profile_model.dart';
import 'entities/dasha_birth_data.dart';

/// Dasha input for [profile]: the exact moment of birth and the natal Moon.
///
/// Vimshottari periods run from the birth moment, so the dasha must start at
/// the birth time in the birth place's time zone, not at midnight on the
/// device. Every screen builds its dasha input here so they all agree.
DashaBirthData dashaBirthDataFor(BirthProfileModel profile, Kundali kundali) {
  return DashaBirthData(
    birthDate: birthInstant(
      profile.dateOfBirth,
      profile.birthTime,
      profile.location.timezone,
    ),
    moonLongitude: kundali.moonLongitude,
  );
}

/// The birth moment as a device-local [DateTime], so it compares correctly
/// with `DateTime.now()`. Falls back to the date at the birth time on this
/// device when the time zone is unknown.
DateTime birthInstant(DateTime date, String birthTime, String timezone) {
  final (hour, minute) = _parseTime(birthTime);
  try {
    final at = tz.TZDateTime(
      tz.getLocation(timezone.trim()),
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    return DateTime.fromMillisecondsSinceEpoch(at.millisecondsSinceEpoch);
  } catch (_) {
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}

/// Reads `HH:mm` (and older `h:mm AM/PM` values). Unreadable times count as
/// midnight, as before.
(int, int) _parseTime(String value) {
  final text = value.trim().toUpperCase();
  final isPm = text.contains('PM');
  final isAm = text.contains('AM');
  final parts = text.replaceAll(RegExp('[^0-9:]'), '').split(':');
  var hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  if (isPm && hour < 12) hour += 12;
  if (isAm && hour == 12) hour = 0;
  return (hour.clamp(0, 23), minute.clamp(0, 59));
}
