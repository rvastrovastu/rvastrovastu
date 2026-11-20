/// Personal consultations: what can be booked, when, and at what price.
library;

import 'package:timezone/timezone.dart' as tz;

enum ConsultationTopic { kundli, marriage, career, vastu }

enum ConsultationMode { phone, whatsapp, video }

/// requested → confirmed (by the astrologer) → paid (by Stripe) →
/// completed; or cancelled.
enum ConsultationStatus { requested, confirmed, paid, completed, cancelled }

/// Booking rules. Change these to match your own schedule and prices.
abstract final class ConsultationConfig {
  /// Where the astrologer is; slots are set in this zone's local time (CST/CDT).
  static const consultantTimezone = 'America/Chicago';

  /// Start-time windows, in minutes after midnight in the zone above.
  /// Weekdays (Mon-Fri): 5:00 PM to 9:00 PM. Weekends: 8:30 AM to 3:00 PM.
  static const weekdayFromMinutes = 17 * 60;
  static const weekdayToMinutes = 21 * 60;
  static const weekendFromMinutes = 8 * 60 + 30;
  static const weekendToMinutes = 15 * 60;

  /// Gap between possible start times.
  static const slotStepMinutes = 30;

  /// How far ahead people can book, and the shortest notice.
  static const bookingDays = 14;
  static const minimumNotice = Duration(hours: 4);

  /// Session lengths offered, in minutes.
  static const lengths = [30, 60];

  /// Fixed prices by length, in rupees for India and dollars elsewhere.
  static const pricesInr = {30: 1100, 60: 2100};
  static const pricesUsd = {30: 19, 60: 35};

  /// Rupee prices go to Indian (+91) phone numbers; everyone else pays in
  /// dollars. The server applies the same rule when it saves a booking, so
  /// changing the phone's time zone doesn't change the price. Until a number
  /// with a country code is typed, an Indian time zone shows rupees as a
  /// first guess.
  static bool usesRupees({String? phone, String? deviceZone}) {
    final number = _normalized(phone ?? '');
    if (number.startsWith('+')) return number.startsWith('+91');
    return deviceZone == 'Asia/Kolkata' || deviceZone == 'Asia/Calcutta';
  }

  /// The Stripe currency code for the price shown: 'inr' or 'usd'. The
  /// payment function charges the matching price from its own table.
  static String currency({String? phone, String? deviceZone}) =>
      usesRupees(phone: phone, deviceZone: deviceZone) ? 'inr' : 'usd';

  /// "₹1,100" or "$19".
  static String priceLabel(
    int minutes, {
    String? phone,
    String? deviceZone,
  }) {
    if (usesRupees(phone: phone, deviceZone: deviceZone)) {
      return '₹${_grouped(pricesInr[minutes] ?? 0)}';
    }
    return '\$${pricesUsd[minutes] ?? 0}';
  }

  /// "+91 98765-43210" → "+919876543210"; a leading 00 counts as +.
  static String _normalized(String phone) {
    final compact = phone.replaceAll(RegExp(r'[\s\-().]'), '');
    return compact.startsWith('00') ? '+${compact.substring(2)}' : compact;
  }

  static String _grouped(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return digits;
    final head = digits.substring(0, digits.length - 3);
    final tail = digits.substring(digits.length - 3);
    // Indian grouping: 1,00,000.
    final parts = <String>[];
    for (var end = head.length; end > 0; end -= 2) {
      parts.insert(0, head.substring(end - 2 < 0 ? 0 : end - 2, end));
    }
    return '${parts.join(',')},$tail';
  }
}

/// Bookable start times, in UTC, grouped by the astrologer's local date
/// (in order). Every hour from [ConsultationConfig.firstHour] to
/// [ConsultationConfig.lastHour], from [now] plus the minimum notice, for
/// the booking window. A start is left out when any half hour of a
/// [minutes]-long session from it is in [taken].
List<(DateTime day, List<DateTime> slots)> availableSlots({
  required DateTime now,
  Set<DateTime> taken = const {},
  int minutes = 30,
  tz.Location? location,
}) {
  final zone = location ?? tz.getLocation(ConsultationConfig.consultantTimezone);
  final earliest = now.toUtc().add(ConsultationConfig.minimumNotice);
  final localNow = tz.TZDateTime.from(now.toUtc(), zone);
  final takenUtc = {for (final t in taken) t.toUtc()};
  bool free(DateTime start) {
    for (var m = 0; m < minutes; m += ConsultationConfig.slotStepMinutes) {
      if (takenUtc.contains(start.add(Duration(minutes: m)))) return false;
    }
    return true;
  }

  final days = <(DateTime, List<DateTime>)>[];
  for (var i = 0; i < ConsultationConfig.bookingDays; i++) {
    final date = DateTime(localNow.year, localNow.month, localNow.day + i);
    final weekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final from = weekend
        ? ConsultationConfig.weekendFromMinutes
        : ConsultationConfig.weekdayFromMinutes;
    final to = weekend
        ? ConsultationConfig.weekendToMinutes
        : ConsultationConfig.weekdayToMinutes;
    final slots = <DateTime>[
      for (var m = from; m <= to; m += ConsultationConfig.slotStepMinutes)
        // A plain UTC DateTime: a TZDateTime never equals a DateTime, so
        // taken slots (plain) would not match.
        DateTime.fromMicrosecondsSinceEpoch(
          tz.TZDateTime(
            zone,
            date.year,
            date.month,
            date.day,
            m ~/ 60,
            m % 60,
          ).microsecondsSinceEpoch,
          isUtc: true,
        ),
    ].where((s) => !s.isBefore(earliest) && free(s)).toList();
    if (slots.isNotEmpty) days.add((date, slots));
  }
  return days;
}

/// A booking request as stored in the `consultation_requests` table.
class ConsultationRequest {
  final String? id;
  final ConsultationTopic topic;
  final int minutes;
  final DateTime slotStart;
  final ConsultationMode mode;
  final String name;
  final String phone;
  final String? email;
  final String? question;
  final String language;
  final String priceLabel;

  /// 'inr' or 'usd'.
  final String currency;

  /// Birth details shared with the astrologer, if the user agreed.
  final Map<String, Object?>? birthDetails;
  final ConsultationStatus status;
  final DateTime? createdAt;

  const ConsultationRequest({
    this.id,
    required this.topic,
    required this.minutes,
    required this.slotStart,
    required this.mode,
    required this.name,
    required this.phone,
    required this.language,
    required this.priceLabel,
    this.currency = 'usd',
    this.email,
    this.question,
    this.birthDetails,
    this.status = ConsultationStatus.requested,
    this.createdAt,
  });

  Map<String, Object?> toInsert() => {
    'topic': topic.name,
    'duration_minutes': minutes,
    'slot_start': slotStart.toUtc().toIso8601String(),
    'mode': mode.name,
    'name': name,
    'phone': phone,
    'email': email,
    'question': question,
    'language': language,
    'price_label': priceLabel,
    'currency': currency,
    'birth_details': birthDetails,
  };

  factory ConsultationRequest.fromRow(Map<String, dynamic> row) =>
      ConsultationRequest(
        id: row['id'] as String?,
        topic:
            ConsultationTopic.values.asNameMap()[row['topic']] ??
            ConsultationTopic.kundli,
        minutes: (row['duration_minutes'] as num?)?.toInt() ?? 30,
        slotStart: DateTime.parse(row['slot_start'] as String).toUtc(),
        mode:
            ConsultationMode.values.asNameMap()[row['mode']] ??
            ConsultationMode.phone,
        name: row['name'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
        email: row['email'] as String?,
        question: row['question'] as String?,
        language: row['language'] as String? ?? 'en',
        priceLabel: row['price_label'] as String? ?? '',
        currency: row['currency'] as String? ?? 'usd',
        status:
            ConsultationStatus.values.asNameMap()[row['status']] ??
            ConsultationStatus.requested,
        createdAt: row['created_at'] == null
            ? null
            : DateTime.parse(row['created_at'] as String),
      );
}

/// A phone number with a country code: + and 8 to 15 digits, spaces and
/// dashes allowed.
/// The dialling code to start the phone field with, from the phone's time
/// zone; null when the region isn't clear.
String? phoneCodeForZone(String zone) {
  if (zone == 'Asia/Kolkata' || zone == 'Asia/Calcutta') return '+91';
  if (zone == 'Europe/London') return '+44';
  if (zone.startsWith('Australia/')) return '+61';
  if (zone == 'Pacific/Auckland') return '+64';
  if (zone == 'Asia/Singapore') return '+65';
  if (zone == 'Asia/Dubai') return '+971';
  const northAmerica = {
    'America/New_York', 'America/Chicago', 'America/Denver',
    'America/Los_Angeles', 'America/Phoenix', 'America/Anchorage',
    'America/Toronto', 'America/Vancouver', 'America/Edmonton',
    'America/Winnipeg', 'America/Halifax', 'America/Detroit',
    'Pacific/Honolulu',
  };
  if (northAmerica.contains(zone)) return '+1';
  return null;
}

bool isValidPhone(String value) {
  // A country code is required: it decides the currency and lets WhatsApp
  // reach the number.
  final digits = value.replaceAll(RegExp(r'[\s\-().]'), '');
  return RegExp(r'^(\+|00)\d{8,15}$').hasMatch(digits);
}
