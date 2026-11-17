import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/festivals/domain/entities/calendar_observance.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/daily_panchang.dart';
import 'package:rv_astro_vastu/features/reminders/domain/entities/reminder_settings.dart';
import 'package:rv_astro_vastu/features/reminders/domain/usecases/plan_reminders.dart';

DailyPanchang _panchang(DateTime date) => DailyPanchang(
  date: date,
  tithi: 'Shukla Shashthi',
  nakshatra: 'Mula',
  yoga: 'Shobhana',
  sunrise: '07:32 AM',
  sunset: '06:52 PM',
  moonrise: '01:17 PM',
  rahuKaal: '11:47 AM – 01:12 PM',
  muhurat: '12:49 PM – 01:35 PM',
);

void main() {
  const plan = PlanReminders();
  final now = DateTime(2026, 10, 16, 9, 30);
  final days = [
    for (var i = 0; i < 14; i++) _panchang(DateTime(2026, 10, 16 + i)),
  ];

  test('nothing is planned while everything is off', () {
    final result = plan(
      settings: const ReminderSettings(configured: true),
      now: now,
      panchangDays: days,
      observances: const [],
    );
    expect(result, isEmpty);
  });

  test('morning reminders skip a time that has already passed today', () {
    final result = plan(
      settings: const ReminderSettings(configured: true, morningEnabled: true),
      now: now,
      panchangDays: days,
      observances: const [],
    );

    expect(result, hasLength(13));
    expect(result.first.at, DateTime(2026, 10, 17, 8));
    expect(result.every((r) => r.kind == ReminderKind.morning), isTrue);
  });

  test('a morning reminder lists that day\'s festival first', () {
    final result = plan(
      settings: const ReminderSettings(configured: true, morningEnabled: true),
      now: now,
      panchangDays: days,
      observances: [
        CalendarObservance(
          date: DateTime(2026, 10, 20),
          id: ObservanceId.pradosh,
        ),
        CalendarObservance(
          date: DateTime(2026, 10, 20),
          id: ObservanceId.dussehra,
        ),
      ],
    );

    final oct20 = result.firstWhere((r) => r.at.day == 20);
    expect(oct20.observances, [ObservanceId.dussehra, ObservanceId.pradosh]);
  });

  test('festival and vrat reminders fire at 6 pm the evening before', () {
    final result = plan(
      settings: const ReminderSettings(
        configured: true,
        festivalsEnabled: true,
        vratsEnabled: true,
      ),
      now: now,
      panchangDays: const [],
      observances: [
        CalendarObservance(
          date: DateTime(2026, 11, 8),
          id: ObservanceId.diwali,
        ),
        CalendarObservance(
          date: DateTime(2026, 11, 8),
          id: ObservanceId.amavasya,
        ),
        CalendarObservance(
          date: DateTime(2026, 10, 22),
          id: ObservanceId.ekadashi,
        ),
      ],
    );

    expect(result.map((r) => r.kind), [
      ReminderKind.vratEve,
      ReminderKind.festivalEve,
    ]);
    expect(result.first.at, DateTime(2026, 10, 21, 18));
    expect(result.last.at, DateTime(2026, 11, 7, 18));
    // Amavasya on Diwali day is covered by the festival reminder.
    expect(
      result.where((r) => r.observances.contains(ObservanceId.amavasya)),
      isEmpty,
    );
  });

  test('reminders more than 60 days out are left for a later sync', () {
    final result = plan(
      settings: const ReminderSettings(
        configured: true,
        festivalsEnabled: true,
      ),
      now: now,
      panchangDays: const [],
      observances: [
        CalendarObservance(
          date: DateTime(2027, 3, 4),
          id: ObservanceId.holi,
        ),
      ],
    );
    expect(result, isEmpty);
  });

  test('the plan is capped for the iOS pending-notification limit', () {
    final many = [
      for (var i = 1; i <= 80; i++)
        CalendarObservance(
          date: DateTime(2026, 10, 16 + (i % 50) + 1),
          id: i.isEven ? ObservanceId.ekadashi : ObservanceId.diwali,
        ),
    ];
    final result = plan(
      settings: ReminderSettings.recommended,
      now: now,
      panchangDays: days,
      observances: many,
    );

    expect(result.length, lessThanOrEqualTo(PlanReminders.maxReminders));
    for (var i = 1; i < result.length; i++) {
      expect(result[i - 1].at.isAfter(result[i].at), isFalse);
    }
    expect(result.map((r) => r.id).toSet(), hasLength(result.length));
  });

  test('transit alerts fire at 9 AM on the day, only when turned on', () {
    final alert = TransitAlert(
      planet: 'Saturn',
      signIndex: 0,
      houseFromMoon: 12,
      favourable: false,
      date: DateTime(2027, 6, 3),
      sadeSati: 'start',
    );
    final past = TransitAlert(
      planet: 'Jupiter',
      signIndex: 3,
      houseFromMoon: 5,
      favourable: true,
      date: DateTime(2026, 10, 1),
    );

    final off = plan(
      settings: const ReminderSettings(configured: true),
      now: now,
      panchangDays: days,
      observances: const [],
      transitAlerts: [alert],
    );
    expect(off, isEmpty);

    final on = plan(
      settings: const ReminderSettings(configured: true, transitsEnabled: true),
      now: now,
      panchangDays: days,
      observances: const [],
      transitAlerts: [alert, past],
    );
    expect(on.single.kind, ReminderKind.transit);
    expect(on.single.at, DateTime(2027, 6, 3, 9));
    expect(on.single.id, 4000);
    expect(on.single.transit!.sadeSati, 'start');
  });

  test('night check-ins at 9 PM for two weeks, only when turned on', () {
    final off = plan(
      settings: const ReminderSettings(configured: true),
      now: now,
      panchangDays: days,
      observances: const [],
    );
    expect(off, isEmpty);

    final on = plan(
      settings: const ReminderSettings(configured: true, checkInEnabled: true),
      now: DateTime(2026, 10, 16, 21, 30),
      panchangDays: days,
      observances: const [],
    );
    expect(on.every((r) => r.kind == ReminderKind.checkIn), isTrue);
    // Tonight's 9 PM has passed, so the first is tomorrow's.
    expect(on, hasLength(PlanReminders.checkInDays - 1));
    expect(on.first.at, DateTime(2026, 10, 17, 21));
    expect(on.first.id, 5001);
  });
}
