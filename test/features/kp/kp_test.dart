import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/kp/kp.dart';
import 'package:rv_astro_vastu/features/kp/kp_repository.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Equal 30° houses from 0° Aries, so house = sign + 1.
KpChart _chart(Map<String, double> planets) => KpChart(
  cusps: [for (var i = 0; i < 12; i++) i * 30.0],
  planets: planets,
  local: DateTime(2026, 10, 22), // Thursday
);

void main() {
  test('star and sub lords follow the Vimshottari split', () {
    expect(kpLords(0.5), const KpLords('Mars', 'Ketu', 'Ketu'));
    expect(kpLords(1.0), const KpLords('Mars', 'Ketu', 'Venus'));
    expect(kpLords(13.5), const KpLords('Mars', 'Venus', 'Venus'));
    expect(kpLords(359.9), const KpLords('Jupiter', 'Mercury', 'Saturn'));
    // Rohini (Moon) starts at 40°; its first sub is the Moon's own.
    expect(kpLords(40.1), const KpLords('Venus', 'Moon', 'Moon'));
  });

  test('249 sub divisions in the zodiac', () {
    var count = 0;
    KpLords? last;
    for (var i = 0; i < 360 * 600; i++) {
      final l = kpLords(i / 600 + 0.0001);
      if (l != last) count++;
      last = l;
    }
    expect(count, 249);
  });

  test('day lord', () {
    expect(dayLord(DateTime(2026, 10, 22)), 'Jupiter');
    expect(dayLord(DateTime(2026, 10, 25)), 'Sun');
  });

  test('houses, ownership and significations', () {
    final chart = _chart({
      'Sun': 10, // Aries, Ketu star → house 1
      'Moon': 45, // Taurus, Moon star
      'Mars': 200,
      'Mercury': 70,
      'Jupiter': 100,
      'Venus': 150,
      'Saturn': 290,
      'Rahu': 330,
      'Ketu': 150,
    });
    expect(chart.houseOf(10), 1);
    expect(chart.houseOf(359), 12);
    expect(chart.housesOwnedBy('Mars'), [1, 8]);
    expect(chart.housesOwnedBy('Rahu'), isEmpty);
    // Sun: star lord Ketu (house 6), Sun in 1, Ketu owns nothing, Sun owns 5.
    expect(chart.significations('Sun'), [6, 1, 5]);
    expect(chart.rulingPlanets.last, ('day', 'Jupiter'));
  });

  test('horary verdict reads the main cusp sub lord', () {
    final chart = _chart({
      'Sun': 10,
      'Moon': 45,
      'Mars': 200,
      'Mercury': 70,
      'Jupiter': 100,
      'Venus': 150,
      'Saturn': 290,
      'Rahu': 330,
      'Ketu': 150,
    });
    // Cusp 7 at 180° (Libra 0°, in Chitra, the Mars star).
    final v = chart.judge(KpQuestion.marriage);
    expect(v.subLord, kpLords(180).sub);
    expect(v.promising, v.supporting.isNotEmpty);
    for (final h in v.supporting) {
      expect(KpQuestion.marriage.favourable, contains(h));
    }
  });

  test('birth moment converts the local clock to UTC', () {
    tzdata.initializeTimeZones();
    expect(
      birthMomentUtc(DateTime(1990, 8, 15), '10:30 PM', 'Asia/Kolkata'),
      DateTime.utc(1990, 8, 15, 17),
    );
    expect(
      birthMomentUtc(DateTime(1990, 1, 1), '12:15 AM', 'Asia/Kolkata'),
      DateTime.utc(1989, 12, 31, 18, 45),
    );
  });

  test('Swiss Ephemeris KP chart has 12 ordered cusps', () async {
    tzdata.initializeTimeZones();
    final chart = await KpRepository().cast(
      utc: DateTime.utc(2026, 10, 22, 6),
      latitude: 28.61,
      longitude: 77.21,
      timezone: 'Asia/Kolkata',
    );
    expect(chart.cusps, hasLength(12));
    expect(chart.planets, hasLength(9));
    expect(
      (chart.planets['Ketu']! - chart.planets['Rahu']! + 360) % 360,
      closeTo(180, 1e-9),
    );
    for (final p in chart.planets.values) {
      expect(chart.houseOf(p), inInclusiveRange(1, 12));
    }
    expect([chart.local.hour, chart.local.minute], [11, 30]);
  });
}
