import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/dosha/domain/entities/kaal_sarp_result.dart';
import 'package:rv_astro_vastu/features/dosha/domain/usecases/check_kaal_sarp_dosha.dart';

import 'dosha_test_helpers.dart';

void main() {
  const check = CheckKaalSarpDosha();

  test('all planets between Rahu and Ketu is a full Kaal Sarp', () {
    // Rahu 10° Aries, Ketu 10° Libra; planets spread in between.
    final kundali = kundaliFrom(
      ascendant: inSign('Aries', 1),
      longitudes: {
        'Rahu': 10,
        'Sun': 40,
        'Moon': 70,
        'Mars': 100,
        'Mercury': 130,
        'Jupiter': 150,
        'Venus': 170,
        'Saturn': 185,
      },
    );

    final result = check(kundali);

    expect(result.status, KaalSarpStatus.full);
    expect(result.direction, KaalSarpDirection.rahuToKetu);
    expect(result.rahuHouse, 1);
    expect(result.ketuHouse, 7);
    expect(result.type, KaalSarpType.anant);
    expect(result.planetsOutside, isEmpty);
  });

  test('planets on the Ketu-to-Rahu side are reported with direction', () {
    final kundali = kundaliFrom(
      ascendant: inSign('Taurus', 1), // Rahu in Aries → house 12.
      longitudes: {
        'Rahu': 10,
        'Sun': 200,
        'Moon': 230,
        'Mars': 260,
        'Mercury': 290,
        'Jupiter': 320,
        'Venus': 340,
        'Saturn': 355,
      },
    );

    final result = check(kundali);

    expect(result.status, KaalSarpStatus.full);
    expect(result.direction, KaalSarpDirection.ketuToRahu);
    expect(result.type, KaalSarpType.sheshnag);
  });

  test('one planet outside the arc is partial', () {
    final kundali = kundaliFrom(
      ascendant: inSign('Aries', 1),
      longitudes: {
        'Rahu': 10,
        'Sun': 40,
        'Moon': 250, // the only planet on the other side
        'Mars': 100,
        'Mercury': 130,
        'Jupiter': 150,
        'Venus': 170,
        'Saturn': 185,
      },
    );

    final result = check(kundali);

    expect(result.status, KaalSarpStatus.partial);
    expect(result.planetsOutside, ['Moon']);
  });

  test('planets on both sides means no Kaal Sarp', () {
    final kundali = kundaliFrom(
      ascendant: inSign('Aries', 1),
      longitudes: {
        'Rahu': 10,
        'Sun': 40,
        'Moon': 250,
        'Mars': 300,
        'Mercury': 130,
        'Jupiter': 150,
        'Venus': 170,
        'Saturn': 185,
      },
    );

    final result = check(kundali);

    expect(result.status, KaalSarpStatus.none);
    expect(result.type, isNull);
    expect(result.isPresent, isFalse);
  });

  test('uses exact degrees: same sign as Rahu but behind it is outside', () {
    // Rahu at 20° Aries; Sun at 5° Aries is behind Rahu (Ketu→Rahu side).
    final kundali = kundaliFrom(
      ascendant: inSign('Aries', 1),
      longitudes: {
        'Rahu': 20,
        'Sun': 5,
        'Moon': 70,
        'Mars': 100,
        'Mercury': 130,
        'Jupiter': 150,
        'Venus': 170,
        'Saturn': 185,
      },
    );

    final result = check(kundali);

    expect(result.status, KaalSarpStatus.partial);
    expect(result.planetsOutside, ['Sun']);
  });
}
