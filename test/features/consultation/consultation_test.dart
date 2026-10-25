import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/consultation/domain/consultation.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('availableSlots', () {
    // 08:00 in India on Saturday 24 Oct 2026 (IST is UTC+5:30).
    final now = DateTime.utc(2026, 10, 24, 2, 30);

    test('hourly from 10:00 to 19:00 India time, after 4 hours notice', () {
      final days = availableSlots(now: now);

      expect(days, hasLength(ConsultationConfig.bookingDays));
      final (firstDay, firstSlots) = days.first;
      expect(firstDay, DateTime(2026, 10, 24));
      // 08:00 + 4 h notice = 12:00, so today starts at 12:00 IST.
      expect(firstSlots.first, DateTime.utc(2026, 10, 24, 6, 30));
      expect(firstSlots.last, DateTime.utc(2026, 10, 24, 13, 30));
      expect(firstSlots, hasLength(8));

      final (_, nextSlots) = days[1];
      expect(nextSlots, hasLength(10));
      expect(nextSlots.first, DateTime.utc(2026, 10, 25, 4, 30));
    });

    test('leaves out taken slots', () {
      final taken = DateTime.utc(2026, 10, 25, 4, 30);
      final days = availableSlots(now: now, taken: {taken});
      final (_, nextSlots) = days[1];
      expect(nextSlots, isNot(contains(taken)));
      expect(nextSlots, hasLength(9));
    });

    test('skips a day with nothing left', () {
      // 18:00 IST: 22:00 is past the last slot, so today is gone.
      final days = availableSlots(now: DateTime.utc(2026, 10, 24, 12, 30));
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
