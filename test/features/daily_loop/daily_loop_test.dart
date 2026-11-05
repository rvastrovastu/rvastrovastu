import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/daily_loop/data/daily_loop_storage.dart';
import 'package:rv_astro_vastu/features/daily_loop/domain/daily_loop.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('pickDailyRemedy', () {
    test('follows the running antardasha lord', () {
      final remedy = pickDailyRemedy(
        date: DateTime(2026, 10, 24),
        mahadasha: 'Saturn',
        antardasha: 'Mercury',
      );
      expect(remedy.planet, 'mercury');
      expect(remedy.forDasha, isTrue);
    });

    test('falls back to the mahadasha, then the weekday planet', () {
      expect(
        pickDailyRemedy(
          date: DateTime(2026, 10, 24),
          mahadasha: 'Venus',
          antardasha: 'Unknown',
        ).planet,
        'venus',
      );

      // 24 Oct 2026 is a Saturday.
      final weekday = pickDailyRemedy(date: DateTime(2026, 10, 24));
      expect(weekday.planet, 'saturn');
      expect(weekday.forDasha, isFalse);
    });

    test('rotates mantra, charity and worship day by day', () {
      final kinds = {
        for (var i = 0; i < 3; i++)
          pickDailyRemedy(
            date: DateTime(2026, 10, 24 + i),
            antardasha: 'Moon',
          ).kind,
      };
      expect(kinds, RemedyKind.values.toSet());
    });
  });

  group('remedyStreak', () {
    final today = DateTime(2026, 10, 24);
    String day(int back) => dayKey(DateTime(2026, 10, 24 - back));

    test('counts back from today', () {
      expect(remedyStreak({day(0), day(1), day(2), day(4)}, today), 3);
    });

    test('keeps yesterday\'s streak while today is still open', () {
      expect(remedyStreak({day(1), day(2)}, today), 2);
    });

    test('is zero after a missed day', () {
      expect(remedyStreak({day(2), day(3)}, today), 0);
      expect(remedyStreak({}, today), 0);
    });

    test('crosses month ends', () {
      final first = DateTime(2026, 11, 1);
      expect(
        remedyStreak({
          dayKey(first),
          dayKey(DateTime(2026, 10, 31)),
          dayKey(DateTime(2026, 10, 30)),
        }, first),
        3,
      );
    });
  });

  group('matchRate', () {
    final today = DateTime(2026, 10, 24);
    String day(int back) => dayKey(DateTime(2026, 10, 24 - back));

    test('needs three answers', () {
      expect(
        matchRate({day(0): CheckIn.yes, day(1): CheckIn.no}, today),
        isNull,
      );
    });

    test('counts yes as one and partly as a half', () {
      final rate = matchRate({
        day(0): CheckIn.yes,
        day(1): CheckIn.partly,
        day(2): CheckIn.no,
        day(3): CheckIn.yes,
      }, today);
      expect(rate?.days, 4);
      expect(rate?.percent, 63); // 2.5 of 4
    });

    test('looks back only over the window', () {
      final rate = matchRate({
        day(0): CheckIn.yes,
        day(1): CheckIn.yes,
        day(2): CheckIn.yes,
        day(40): CheckIn.no,
      }, today);
      expect(rate?.days, 3);
      expect(rate?.percent, 100);
    });
  });

  group('DailyLoopStorage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('starts empty', () async {
      final record = await const DailyLoopStorage().load();
      expect(record.remedyDays, isEmpty);
      expect(record.checkIns, isEmpty);
    });

    test('saves and loads, dropping very old days', () async {
      const storage = DailyLoopStorage();
      final today = DateTime(2026, 10, 24);
      final old = dayKey(DateTime(2025, 1, 1));

      await storage.save(
        DailyLoopRecord(
          remedyDays: {'2026-10-24', '2026-10-23', old},
          checkIns: {'2026-10-23': CheckIn.partly, old: CheckIn.yes},
        ),
        today,
      );

      final loaded = await storage.load();
      expect(loaded.remedyDays, {'2026-10-24', '2026-10-23'});
      expect(loaded.checkIns, {'2026-10-23': CheckIn.partly});
    });
  });
}
