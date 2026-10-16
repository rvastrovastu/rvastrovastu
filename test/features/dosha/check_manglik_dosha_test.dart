import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/dosha/domain/entities/manglik_result.dart';
import 'package:rv_astro_vastu/features/dosha/domain/usecases/check_manglik_dosha.dart';

import 'dosha_test_helpers.dart';

void main() {
  const check = CheckManglikDosha();

  // Base chart: Leo lagna, nothing Manglik. Mars in Leo's 3rd (Libra) is
  // also the 3rd/5th from Moon/Venus below.
  Map<String, double> base() => {
    'Sun': inSign('Leo'),
    'Moon': inSign('Leo', 20),
    'Mars': inSign('Libra'),
    'Mercury': inSign('Virgo'),
    'Jupiter': inSign('Gemini'),
    'Venus': inSign('Gemini', 5),
    'Saturn': inSign('Taurus'),
    'Rahu': inSign('Aries'),
  };

  test('no Manglik house from any reference', () {
    final result = check(
      kundaliFrom(ascendant: inSign('Leo', 1), longitudes: base()),
    );

    expect(result.status, ManglikStatus.none);
    expect(result.marsHouseFromLagna, 3);
    expect(result.hasManglikPlacement, isFalse);
    expect(result.cancellations, isEmpty);
  });

  test('Mars in the 7th from Lagna is Manglik', () {
    // Leo lagna → Aquarius is the 7th. Moon in Leo also sees it as 7th.
    final longitudes = base()
      ..['Mars'] = inSign('Aquarius')
      ..['Jupiter'] = inSign('Cancer'); // 8th from Jupiter: no aspect.

    final result = check(
      kundaliFrom(ascendant: inSign('Leo', 1), longitudes: longitudes),
    );

    expect(result.status, ManglikStatus.present);
    expect(result.marsHouseFromLagna, 7);
    expect(result.fromLagna, isTrue);
    expect(result.fromMoon, isTrue);
    expect(result.isEffectivelyManglik, isTrue);
  });

  test('Moon-only placement is mild', () {
    // Lagna Aries, Mars in Leo = 5th from Lagna (not Manglik).
    // Moon in Cancer → Leo is the 2nd from Moon (Manglik).
    final longitudes = base()
      ..['Moon'] = inSign('Cancer')
      ..['Mars'] = inSign('Leo')
      ..['Venus'] = inSign('Aries') // Leo 5th from Venus.
      ..['Jupiter'] = inSign('Taurus'); // Leo 4th from Jupiter: no aspect.

    final result = check(
      kundaliFrom(ascendant: inSign('Aries', 1), longitudes: longitudes),
    );

    expect(result.fromLagna, isFalse);
    expect(result.fromMoon, isTrue);
    expect(result.fromVenus, isFalse);
    expect(result.status, ManglikStatus.mild);
  });

  test('Mars in own sign cancels the dosha', () {
    // Leo lagna → Scorpio is the 4th; Mars owns Scorpio.
    final longitudes = base()
      ..['Mars'] = inSign('Scorpio')
      ..['Jupiter'] = inSign('Leo', 2); // 4th from Jupiter: no aspect.

    final result = check(
      kundaliFrom(ascendant: inSign('Leo', 1), longitudes: longitudes),
    );

    expect(result.fromLagna, isTrue);
    expect(result.status, ManglikStatus.cancelled);
    expect(result.cancellations, [ManglikCancellation.marsInOwnOrExaltedSign]);
    expect(result.isEffectivelyManglik, isFalse);
  });

  test('Jupiter 7th aspect on Mars is a cancellation', () {
    // Leo lagna, Mars in Aquarius (7th). Jupiter in Leo aspects Aquarius.
    final longitudes = base()
      ..['Mars'] = inSign('Aquarius')
      ..['Jupiter'] = inSign('Leo', 5);

    final result = check(
      kundaliFrom(ascendant: inSign('Leo', 1), longitudes: longitudes),
    );

    expect(result.status, ManglikStatus.cancelled);
    expect(
      result.cancellations,
      contains(ManglikCancellation.jupiterAspectsMars),
    );
  });

  test('compareManglik treats two Manglik charts as balanced', () {
    final manglik = check(
      kundaliFrom(
        ascendant: inSign('Leo', 1),
        longitudes: base()
          ..['Mars'] = inSign('Aquarius')
          ..['Jupiter'] = inSign('Cancer'),
      ),
    );
    final clear = check(
      kundaliFrom(ascendant: inSign('Leo', 1), longitudes: base()),
    );

    expect(compareManglik(manglik, manglik), ManglikMatch.bothManglik);
    expect(compareManglik(clear, clear), ManglikMatch.neitherManglik);
    expect(compareManglik(manglik, clear), ManglikMatch.onlyOneManglik);
  });

  test('throws when Mars is missing', () {
    final longitudes = base()..remove('Mars');
    expect(
      () => check(kundaliFrom(ascendant: 1, longitudes: longitudes)),
      throwsArgumentError,
    );
  });
}
