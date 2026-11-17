import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/consultation/domain/consultation.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('availableSlots (Chicago hours)', () {
    // Sat 24 Oct 2026, 08:00 Chicago (CDT, UTC-5) = 13:00 UTC.
    // Minimum notice is 4 hours, so the first bookable time is 12:00 Chicago.
    final now = DateTime.utc(2026, 10, 24, 13, 0);

    test('weekend 08:30-15:00 Chicago, after 4 hours notice', () {
      final days = availableSlots(now: now);

      expect(days, hasLength(ConsultationConfig.bookingDays));
      final (firstDay, firstSlots) = days.first;
      expect(firstDay, DateTime(2026, 10, 24));
      // 12:00 to 15:00 Chicago in 30-minute steps: 7 slots.
      expect(firstSlots, hasLength(7));
      expect(firstSlots.first, DateTime.utc(2026, 10, 24, 17, 0));
      expect(firstSlots.last, DateTime.utc(2026, 10, 24, 20, 0));

      // Sunday: 08:30 to 15:00 Chicago = 14 slots.
      final (_, sundaySlots) = days[1];
      expect(sundaySlots, hasLength(14));
      expect(sundaySlots.first, DateTime.utc(2026, 10, 25, 13, 30));
      expect(sundaySlots.last, DateTime.utc(2026, 10, 25, 20, 0));
    });

    test('leaves out taken slots', () {
      final taken = DateTime.utc(2026, 10, 25, 13, 30);
      final days = availableSlots(now: now, taken: {taken});
      final (_, sundaySlots) = days[1];
      expect(sundaySlots, isNot(contains(taken)));
      expect(sundaySlots, hasLength(13));
    });

    test('skips a day with nothing left', () {
      // Sat 19:30 Chicago: 4 hours notice pushes past the 15:00 weekend end.
      final days = availableSlots(now: DateTime.utc(2026, 10, 25, 0, 30));
      expect(days.first.$1, DateTime(2026, 10, 25));
    });
  });

  group('prices', () {
    test('rupees for Indian time zones, dollars elsewhere', () {
      expect(ConsultationConfig.priceLabel(30, 'Asia/Kolkata'), '₹1,100');
      expect(ConsultationConfig.priceLabel(60, 'Asia/Calcutta'), '₹2,100');
      expect(ConsultationConfig.priceLabel(30, 'America/Chicago'), r'$19');
      expect(ConsultationConfig.priceLabel(60, null), r'$35');
      expect(ConsultationConfig.currency('Asia/Kolkata'), 'inr');
      expect(ConsultationConfig.currency('America/Chicago'), 'usd');
    });
  });

  test('phone numbers need 8 to 15 digits', () {
    expect(isValidPhone('+91 98765 43210'), isTrue);
    expect(isValidPhone('(214) 555-0182'), isTrue);
    expect(isValidPhone('12345'), isFalse);
    expect(isValidPhone('call me'), isFalse);
  });

  test('a request round-trips through a database row', () {
    final request = ConsultationRequest(
      topic: ConsultationTopic.vastu,
      minutes: 60,
      slotStart: DateTime.utc(2026, 10, 25, 4, 30),
      mode: ConsultationMode.video,
      name: 'Ritesh',
      phone: '+1 214 555 0182',
      language: 'hi',
      priceLabel: r'$35',
      currency: 'usd',
    );
    final row = {
      ...request.toInsert(),
      'id': 'abc',
      'status': 'paid',
      'created_at': '2026-10-24T02:30:00Z',
    };
    final back = ConsultationRequest.fromRow(row);

    expect(back.id, 'abc');
    expect(back.topic, ConsultationTopic.vastu);
    expect(back.minutes, 60);
    expect(back.slotStart, request.slotStart);
    expect(back.mode, ConsultationMode.video);
    expect(back.status, ConsultationStatus.paid);
    expect(back.currency, 'usd');
    expect(back.priceLabel, r'$35');
  });
}
