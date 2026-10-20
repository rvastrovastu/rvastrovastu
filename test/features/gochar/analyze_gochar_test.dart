import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/dosha/domain/entities/zodiac_signs.dart';
import 'package:rv_astro_vastu/features/gochar/data/repositories/swiss_ephemeris_transit_repository.dart';
import 'package:rv_astro_vastu/features/gochar/domain/entities/transit.dart';
import 'package:rv_astro_vastu/features/gochar/domain/usecases/analyze_gochar.dart';

/// Lahiri sign periods 2025–2029 (pyswisseph, same scan as the app).
List<PlanetSignPeriod> _periods(
  TransitPlanet planet,
  List<(String, String, String)> rows,
) => [
  for (final (sign, start, end) in rows)
    PlanetSignPeriod(
      planet: planet,
      signIndex: zodiacSignIndex(sign),
      start: DateTime.parse('${start}T00:00:00Z'),
      end: DateTime.parse('${end}T00:00:00Z'),
    ),
];

final _jupiter = _periods(TransitPlanet.jupiter, [
  ('Taurus', '2025-01-01', '2025-05-14'),
  ('Gemini', '2025-05-14', '2025-10-18'),
  ('Cancer', '2025-10-18', '2025-12-05'),
  ('Gemini', '2025-12-05', '2026-06-01'),
  ('Cancer', '2026-06-01', '2026-10-31'),
  ('Leo', '2026-10-31', '2027-01-24'),
  ('Cancer', '2027-01-24', '2027-06-26'),
  ('Leo', '2027-06-26', '2027-11-26'),
  ('Virgo', '2027-11-26', '2028-02-28'),
  ('Leo', '2028-02-28', '2028-07-24'),
  ('Virgo', '2028-07-24', '2028-12-26'),
  ('Libra', '2028-12-26', '2029-01-01'),
]);

final _saturn = _periods(TransitPlanet.saturn, [
  ('Aquarius', '2025-01-01', '2025-03-29'),
  ('Pisces', '2025-03-29', '2027-06-03'),
  ('Aries', '2027-06-03', '2027-10-20'),
  ('Pisces', '2027-10-20', '2028-02-23'),
  ('Aries', '2028-02-23', '2029-01-01'),
]);

final _rahu = _periods(TransitPlanet.rahu, [
  ('Pisces', '2025-01-01', '2025-05-18'),
  ('Aquarius', '2025-05-18', '2026-12-05'),
  ('Capricorn', '2026-12-05', '2028-06-23'),
  ('Sagittarius', '2028-06-23', '2029-01-01'),
]);

final _ketu = [
  for (final p in _rahu)
    PlanetSignPeriod(
      planet: TransitPlanet.ketu,
      signIndex: (p.signIndex + 6) % 12,
      start: p.start,
      end: p.end,
    ),
];

void main() {
  const analyze = AnalyzeGochar();
  final now = DateTime.utc(2026, 10, 16, 12);

  GocharReport leoMoon() => analyze(
    moonSign: 'Leo',
    lagnaSign: 'Virgo',
    periods: {
      TransitPlanet.jupiter: _jupiter,
      TransitPlanet.saturn: _saturn,
      TransitPlanet.rahu: _rahu,
      TransitPlanet.ketu: _ketu,
    },
    now: now,
  );

  test('current transits counted from a Leo Moon in Oct 2026', () {
    final report = leoMoon();
    final byPlanet = {for (final r in report.current) r.planet: r};

    final jupiter = byPlanet[TransitPlanet.jupiter]!;
    expect(zodiacSigns[jupiter.signIndex], 'Cancer');
    expect(jupiter.houseFromMoon, 12);
    expect(jupiter.houseFromLagna, 11);
    expect(jupiter.tone, TransitTone.challenging);
    expect(jupiter.until, DateTime.parse('2026-10-31T00:00:00Z'));
    expect(zodiacSigns[jupiter.nextSignIndex!], 'Leo');

    final saturn = byPlanet[TransitPlanet.saturn]!;
    expect(zodiacSigns[saturn.signIndex], 'Pisces');
    expect(saturn.houseFromMoon, 8);
    expect(saturn.since, DateTime.parse('2025-03-29T00:00:00Z'));

    expect(zodiacSigns[byPlanet[TransitPlanet.rahu]!.signIndex], 'Aquarius');
    expect(byPlanet[TransitPlanet.ketu]!.houseFromMoon, 1);
  });

  test('upcoming changes are sorted and read from the Moon', () {
    final upcoming = leoMoon().upcoming;

    expect(upcoming.first.planet, TransitPlanet.jupiter);
    expect(upcoming.first.date, DateTime.parse('2026-10-31T00:00:00Z'));

    final rahuToCapricorn = upcoming.firstWhere(
      (u) => u.planet == TransitPlanet.rahu,
    );
    expect(zodiacSigns[rahuToCapricorn.signIndex], 'Capricorn');
    expect(rahuToCapricorn.houseFromMoon, 6);
    expect(rahuToCapricorn.tone, TransitTone.favourable);

    for (var i = 1; i < upcoming.length; i++) {
      expect(upcoming[i - 1].date.isAfter(upcoming[i].date), isFalse);
    }
    // Two-year window only.
    expect(
      upcoming.every((u) => u.date.isBefore(DateTime.utc(2028, 10, 16))),
      isTrue,
    );
  });

  test('classical favourable houses', () {
    expect(
      AnalyzeGochar.toneFor(TransitPlanet.jupiter, 11),
      TransitTone.favourable,
    );
    expect(
      AnalyzeGochar.toneFor(TransitPlanet.jupiter, 8),
      TransitTone.challenging,
    );
    expect(
      AnalyzeGochar.toneFor(TransitPlanet.saturn, 3),
      TransitTone.favourable,
    );
    expect(
      AnalyzeGochar.toneFor(TransitPlanet.saturn, 1),
      TransitTone.challenging,
    );
  });

  test('Swiss Ephemeris finds the May 2025 ingresses', () async {
    final periods = await SwissEphemerisTransitRepository().signPeriods(
      fromUtc: DateTime.utc(2025),
      toUtc: DateTime.utc(2026),
    );

    PlanetSignPeriod entering(TransitPlanet planet, String sign) =>
        periods[planet]!.firstWhere(
          (p) => p.signIndex == zodiacSignIndex(sign),
        );

    final jupiter = entering(TransitPlanet.jupiter, 'Gemini').start;
    final rahu = entering(TransitPlanet.rahu, 'Aquarius').start;
    final ketu = entering(TransitPlanet.ketu, 'Leo').start;

    expect(
      jupiter.difference(DateTime.utc(2025, 5, 14)).inHours.abs(),
      lessThan(36),
    );
    expect(
      rahu.difference(DateTime.utc(2025, 5, 18)).inHours.abs(),
      lessThan(36),
    );
    expect(ketu, rahu);
  });
}
