import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/daily_loop/domain/personal_muhurat.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/day_divisions.dart';
import 'package:rv_astro_vastu/features/your_day/domain/day_strength.dart';

/// Sunday 18 Oct 2026 with a 12-hour day: sunrise 06:00, sunset 18:00
/// UTC, so every Choghadiya is 90 minutes and every hora an hour.
///
/// Day Choghadiya: 06 Udveg, 07:30 Chal, 09 Labh, 10:30 Amrit, 12 Kaal,
/// 13:30 Shubh, 15 Rog, 16:30 Udveg; evening: 18 Shubh, 19:30 Amrit.
/// Horas from 06: Sun, Venus, Mercury, Moon, Saturn, Jupiter, Mars, Sun,
/// Venus, Mercury, Moon, Saturn; from 18: Jupiter, Mars, Sun.
/// Rahu Kaal 16:30, Yamaganda 12:00, Gulika 15:00; Abhijit 11:36–12:24.
final _sunday = DayDivisions.calculate(
  SunTimes(
    sunrise: DateTime.utc(2026, 10, 18, 6),
    sunset: DateTime.utc(2026, 10, 18, 18),
    nextSunrise: DateTime.utc(2026, 10, 19, 6),
  ),
  DateTime.sunday,
);

DateTime _utc(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 10, 18, hour, minute);

List<MuhuratWindow> _find({
  DateTime? now,
  MuhuratPurpose purpose = MuhuratPurpose.start,
  int birth = 10,
  int nakshatraNow = 10,
  DateTime? nakshatraEnds,
  int limit = 3,
}) => const FindPersonalMuhurat()(
  days: [_sunday],
  now: now ?? _utc(8),
  birthNakshatra: birth,
  nakshatraNow: nakshatraNow,
  nakshatraEndsUtc: nakshatraEnds ?? DateTime.utc(2026, 10, 20),
  purpose: purpose,
  limit: limit,
);

void main() {
  test('picks Amrit in Jupiter hora over Abhijit as the best start', () {
    final windows = _find();

    expect(windows, hasLength(3));
    expect(windows[0].start, _utc(11));
    expect(windows[0].end, _utc(12));
    expect(windows[0].choghadiya, Choghadiya.amrit);
    expect(windows[0].hora, 'Jupiter');
    expect(windows[0].score, 6);

    expect(windows[1].start, _utc(20));
    expect(windows[1].hora, 'Sun');
    expect(windows[1].score, 5);

    // Ties go to the earlier window.
    expect(windows[2].start, _utc(13, 30));
    expect(windows[2].score, 4);
  });

  test('never suggests a bad Choghadiya, Rahu Kaal, Yamaganda or Gulika', () {
    final windows = _find(now: _utc(6), limit: 100);
    final blocked = [_sunday.rahuKaal, _sunday.yamaganda, _sunday.gulika];

    expect(windows, isNotEmpty);
    for (final w in windows) {
      expect(w.choghadiya.quality, ChoghadiyaQuality.good);
      for (final b in blocked) {
        expect(w.start.isBefore(b.end) && b.start.isBefore(w.end), isFalse);
      }
      expect(w.length >= FindPersonalMuhurat.minimum, isTrue);
    }
  });

  test('only windows still ahead, trimmed to now', () {
    final windows = _find(now: _utc(11, 20), limit: 100);

    for (final w in windows) {
      expect(w.start.isBefore(_utc(11, 20)), isFalse);
    }
    expect(windows.first.start, _utc(11, 20));
    expect(windows.first.end, _utc(12));
  });

  test('a window shorter than 20 minutes is skipped', () {
    final windows = _find(now: _utc(11, 45), limit: 100);
    expect(windows.where((w) => w.start == _utc(11, 45)), isEmpty);
  });

  test('Chal counts for travel only', () {
    final travel = _find(now: _utc(7), purpose: MuhuratPurpose.travel);
    final start = _find(
      now: _utc(7),
      purpose: MuhuratPurpose.start,
      limit: 100,
    );

    expect(travel.first.choghadiya, Choghadiya.chal);
    expect(travel.first.start, _utc(7, 30));
    expect(start.where((w) => w.choghadiya == Choghadiya.chal), isEmpty);
  });

  test('the birth star moves every score', () {
    // Counted from the birth star: +1 is Sampat (good), +2 Vipat (bad).
    final sampat = _find(birth: 10, nakshatraNow: 11);
    final vipat = _find(birth: 10, nakshatraNow: 12);

    expect(sampat.first.tara, Tara.sampat);
    expect(sampat.first.score, 7);
    expect(vipat.first.tara, Tara.vipat);
    expect(vipat.first.score, 4);
  });

  test('uses the next nakshatra after the Moon moves on', () {
    final windows = _find(
      birth: 10,
      nakshatraNow: 11,
      nakshatraEnds: _utc(15),
      limit: 100,
    );

    for (final w in windows) {
      expect(w.tara, w.start.isBefore(_utc(15)) ? Tara.sampat : Tara.vipat);
    }
  });
}
