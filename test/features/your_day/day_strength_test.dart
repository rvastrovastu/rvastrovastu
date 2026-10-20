import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/your_day/domain/day_strength.dart';

void main() {
  test('Tara counts from the birth nakshatra in cycles of nine', () {
    const rohini = 3;
    expect(Tara.of(rohini, rohini), Tara.janma);
    expect(Tara.of(rohini, 4), Tara.sampat); // Mrigashira
    expect(Tara.of(rohini, 5), Tara.vipat); // Ardra
    expect(Tara.of(rohini, 9), Tara.vadha); // Magha, 7th
    expect(Tara.of(rohini, 12), Tara.janma); // Hasta, 10th
    // Krittika is the 27th from Rohini, the last of the third cycle.
    expect(Tara.of(rohini, 2), Tara.paramaMitra);
  });

  test('Tara strengths', () {
    expect(
      Tara.values.where((t) => t.strength == Strength.bad),
      [Tara.vipat, Tara.pratyari, Tara.vadha],
    );
    expect(Tara.janma.strength, Strength.weak);
  });

  test('Chandra Bala and Chandrashtama from the natal Moon sign', () {
    // Natal Moon in Leo (Purva Phalguni), the 13 Dec 1987 Delhi chart.
    DayStrength at(double transit) =>
        DayStrength.fromLongitudes(natalMoon: 139.01, transitMoon: transit);

    expect(at(139.01).birthNakshatra, 10);
    expect(at(139.01).natalMoonSign, 4);

    final pisces = at(345);
    expect(pisces.chandraHouse, 8);
    expect(pisces.isChandrashtama, isTrue);
    expect(pisces.chandraBala, Strength.bad);
    expect(pisces.verdict, DayVerdict.caution);

    final libra = at(190); // 3rd from Leo, Swati
    expect(libra.chandraHouse, 3);
    expect(libra.chandraBala, Strength.good);
    // Swati (14) is the 5th from Purva Phalguni (10): Pratyari.
    expect(libra.tara, Tara.pratyari);
    expect(libra.verdict, DayVerdict.caution);

    final libraLater = at(205); // Vishakha (15), 6th: Sadhaka
    expect(libraLater.tara, Tara.sadhaka);
    expect(libraLater.verdict, DayVerdict.good);

    final virgo = at(175); // 2nd from Leo (weak), Chitra (13): Kshema
    expect(virgo.chandraBala, Strength.weak);
    expect(virgo.tara, Tara.kshema);
    expect(virgo.verdict, DayVerdict.mixed);
  });

  test('indices wrap and accept negative longitudes', () {
    expect(nakshatraIndexOf(359.99), 26);
    expect(nakshatraIndexOf(-0.5), 26);
    expect(signIndexOf(-0.5), 11);
    expect(nakshatraNames, hasLength(27));
  });
}
