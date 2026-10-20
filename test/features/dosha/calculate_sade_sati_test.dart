import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/dosha/domain/entities/sade_sati.dart';
import 'package:rv_astro_vastu/features/dosha/domain/entities/zodiac_signs.dart';
import 'package:rv_astro_vastu/features/dosha/domain/usecases/calculate_sade_sati.dart';

import 'dosha_test_helpers.dart';

DateTime _d(String value) => DateTime.parse('${value}T12:00:00Z');

void main() {
  const calculate = CalculateSadeSati();

  test('Aquarius Moon in Oct 2026 is in the setting phase', () {
    final report = calculate(
      moonSign: 'Aquarius',
      saturnPeriods: saturnPeriods,
      referenceDate: _d('2026-10-16'),
    );

    expect(report.isActive, isTrue);
    expect(report.currentPhase, SadeSatiPhase.setting);
    expect(report.saturnSignIndex, zodiacSignIndex('Pisces'));

    final cycle = report.currentCycle!;
    expect(cycle.start, DateTime.parse('2020-01-24T00:00:00Z'));
    // Includes the retrograde return to Pisces in late 2027.
    expect(cycle.end, DateTime.parse('2028-02-23T00:00:00Z'));
    expect(
      cycle.phaseStart(SadeSatiPhase.peak),
      DateTime.parse('2022-04-29T00:00:00Z'),
    );
  });

  test('retrograde exit inside a cycle: active, no phase', () {
    final report = calculate(
      moonSign: 'Aquarius',
      saturnPeriods: saturnPeriods,
      referenceDate: _d('2027-08-01'), // Saturn briefly in Aries.
    );

    expect(report.isActive, isTrue);
    expect(report.currentPhase, isNull);
  });

  test('Pisces Moon is at its peak while Saturn transits Pisces', () {
    final report = calculate(
      moonSign: 'Pisces',
      saturnPeriods: saturnPeriods,
      referenceDate: _d('2026-10-16'),
    );

    expect(report.currentPhase, SadeSatiPhase.peak);
    // First Aquarius entry, even though Saturn dipped back into Capricorn
    // for six months before returning.
    expect(
      report.currentCycle!.start,
      DateTime.parse('2022-04-29T00:00:00Z'),
    );
  });

  test('Cancer Moon is not in Sade Sati and gets the next cycle', () {
    final report = calculate(
      moonSign: 'Cancer',
      saturnPeriods: saturnPeriods,
      referenceDate: _d('2026-10-16'),
    );

    expect(report.isActive, isFalse);
    expect(report.currentPhase, isNull);
    // Saturn in Pisces is the 9th from Cancer: no Dhaiya either.
    expect(report.currentDhaiya, isNull);

    final next = report.nextCycle!;
    expect(next.start, DateTime.parse('2032-05-30T00:00:00Z')); // Gemini
    // Saturn leaves Leo in Oct 2038 but returns from Apr to Jul 2039.
    expect(next.end, DateTime.parse('2039-07-12T00:00:00Z'));
  });

  test('Leo Moon has Ashtama Shani (8th) while Saturn is in Pisces', () {
    final report = calculate(
      moonSign: 'Leo',
      saturnPeriods: saturnPeriods,
      referenceDate: _d('2026-10-16'),
    );

    expect(report.isActive, isFalse);
    expect(report.currentDhaiya, ShaniDhaiya.eighth);
  });

  test('Sagittarius Moon has Kantaka Shani (4th) in 2026', () {
    final report = calculate(
      moonSign: 'Sagittarius',
      saturnPeriods: saturnPeriods,
      referenceDate: _d('2026-10-16'),
    );

    expect(report.currentDhaiya, ShaniDhaiya.fourth);
  });

  test('past cycles are kept separate from later ones', () {
    final report = calculate(
      moonSign: 'Capricorn',
      saturnPeriods: saturnPeriods,
      referenceDate: _d('2026-10-16'),
    );

    // Sagittarius 2017 → Aquarius exit 2025: one cycle in range.
    expect(report.cycles, hasLength(1));
    expect(report.cycles.single.start, DateTime.parse('2017-01-26T00:00:00Z'));
    expect(report.cycles.single.end, DateTime.parse('2025-03-29T00:00:00Z'));
    expect(report.isActive, isFalse);
  });

  test('rejects an unknown Moon sign', () {
    expect(
      () => calculate(
        moonSign: 'Ophiuchus',
        saturnPeriods: saturnPeriods,
        referenceDate: _d('2026-10-16'),
      ),
      throwsArgumentError,
    );
  });
}
