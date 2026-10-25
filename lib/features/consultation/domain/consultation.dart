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
  /// Where the astrologer is; slots are set in this zone's local time.
  static const consultantTimezone = 'Asia/Kolkata';

  /// First and last start times of the day, in the astrologer's time.
  static const firstHour = 10;
  static const lastHour = 19;

  /// How far ahead people can book, and the shortest notice.
  static const bookingDays = 14;
  static const minimumNotice = Duration(hours: 4);

  /// Session lengths offered, in minutes.
  static const lengths = [30, 60];

  /// Fixed prices by length, in rupees for India and dollars elsewhere.
  static const pricesInr = {30: 1100, 60: 2100};
  static const pricesUsd = {30: 19, 60: 35};

  /// Phones set to an Indian time zone see rupee prices.
  static bool usesRupees(String? deviceZone) =>
      deviceZone == 'Asia/Kolkata' || deviceZone == 'Asia/Calcutta';

  /// The Stripe currency code for the price shown: 'inr' or 'usd'. The
  /// payment function charges the matching price from its own table.
  static String currency(String? deviceZone) =>
      usesRupees(deviceZone) ? 'inr' : 'usd';

  /// "₹1,100" or "$19".
  static String priceLabel(int minutes, String? deviceZone) {
    if (usesRupees(deviceZone)) {
      return '₹${_grouped(pricesInr[minutes] ?? 0)}';
    }
    return '\$${pricesUsd[minutes] ?? 0}';
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
/// the booking window; [taken] slots are left out.
List<(DateTime day, List<DateTime> slots)> availableSlots({
  required DateTime now,
  Set<DateTime> taken = const {},
  tz.Location? location,
}) {
  final zone = location ?? tz.getLocation(ConsultationConfig.consultantTimezone);
  final earliest = now.toUtc().add(ConsultationConfig.minimumNotice);
  final localNow = tz.TZDateTime.from(now.toUtc(), zone);
  final takenUtc = {for (final t in taken) t.toUtc()};

  final days = <(DateTime, List<DateTime>)>[];
  for (var i = 0; i < ConsultationConfig.bookingDays; i++) {
    final date = DateTime(localNow.year, localNow.month, localNow.day + i);
    final slots = <DateTime>[
      for (
        var hour = ConsultationConfig.firstHour;
        hour <= ConsultationConfig.lastHour;
        hour++
      )
        // A plain UTC DateTime: a TZDateTime never equals a DateTime, so
        // taken slots (plain) would not match.
        DateTime.fromMicrosecondsSinceEpoch(
          tz.TZDateTime(
            zone,
            date.year,
            date.month,
            date.day,
            hour,
          ).microsecondsSinceEpoch,
          isUtc: true,
        ),
    ].where((s) => !s.isBefore(earliest) && !takenUtc.contains(s)).toList();
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
bool isValidPhone(String value) {
  final digits = value.replaceAll(RegExp(r'[\s\-()]'), '');
  return RegExp(r'^\+?\d{8,15}$').hasMatch(digits);
}
