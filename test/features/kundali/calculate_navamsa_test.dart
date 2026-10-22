import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/kundali.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/planet_position.dart';
import 'package:rv_astro_vastu/features/dosha/domain/entities/zodiac_signs.dart';
import 'package:rv_astro_vastu/features/kundali/domain/usecases/calculate_navamsa.dart';
import 'package:rv_astro_vastu/features/kundali/presentation/widgets/rashi_chart/south_indian_chart.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

/// A real chart (13 Dec 1987, 00:42, Delhi) with sidereal longitudes from
/// the app's Swiss Ephemeris log.
Kundali _sampleKundali() {
  PlanetPosition p(String name, double longitude) => PlanetPosition(
    planet: name,
    sign: zodiacSigns[(longitude / 30).floor()],
    house: houseFrom(5, (longitude / 30).floor()), // Virgo lagna
    longitude: longitude,
    degree: longitude % 30,
  );

  return Kundali(
    ascendant: 'Virgo',
    ayanamsa: 23.69,
    ascendantDegree: 2.924555,
    moonLongitude: 139.006109,
    moonSign: 'Leo',
    sunSign: 'Scorpio',
    nakshatra: 'Purva Phalguni',
    nakshatraPada: 2,
    planets: [
      p('Sun', 236.531801),
      p('Moon', 139.006109),
      p('Mars', 198.548654),
      p('Mercury', 230.697764),
      p('Jupiter', 356.088028),
      p('Venus', 264.585274),
      p('Saturn', 239.516221),
    ],
  );
}

void main() {
  group('navamsa sign mapping', () {
    test('fire signs start from Aries', () {
      expect(CalculateNavamsa.navamsaSignIndex(0), 0);
      expect(CalculateNavamsa.navamsaSignIndex(3.4), 1);
      expect(CalculateNavamsa.navamsaSignIndex(29.9), 8);
    });

    test('earth, air and water signs start from Capricorn, Libra, Cancer', () {
      expect(CalculateNavamsa.navamsaSignIndex(30), 9); // Taurus → Capricorn
      expect(CalculateNavamsa.navamsaSignIndex(60), 6); // Gemini → Libra
      expect(CalculateNavamsa.navamsaSignIndex(90), 3); // Cancer → Cancer
    });

    test('the last navamsa of Pisces is Pisces', () {
      expect(CalculateNavamsa.navamsaSignIndex(359.9), 11);
    });
  });

  test('sample chart navamsa positions', () {
    final navamsa = const CalculateNavamsa()(_sampleKundali());

    expect(navamsa.lagnaSign, 'Capricorn');

    String signOf(String planet) => navamsa.chart.houses
        .firstWhere((h) => h.planets.any((p) => p.planet == planet))
        .sign;

    expect(signOf('Sun'), 'Aquarius');
    expect(signOf('Moon'), 'Virgo');
    expect(signOf('Mars'), 'Pisces');
    expect(signOf('Mercury'), 'Capricorn');
    expect(signOf('Jupiter'), 'Aquarius');
    expect(signOf('Venus'), 'Scorpio');
    expect(signOf('Saturn'), 'Pisces');

    // House 1 is the Navamsa Lagna; Mercury sits in it.
    final first = navamsa.chart.house(1)!;
    expect(first.sign, 'Capricorn');
    expect(first.planets.map((p) => p.planet), ['Mercury']);
    expect(navamsa.vargottama, isEmpty);
  });

  test('a planet in the same sign in D1 and D9 is vargottama', () {
    final kundali = _sampleKundali();
    // 1° Aries is Aries navamsa.
    final withVargottama = Kundali(
      ascendant: kundali.ascendant,
      ayanamsa: kundali.ayanamsa,
      ascendantDegree: kundali.ascendantDegree,
      moonLongitude: kundali.moonLongitude,
      moonSign: kundali.moonSign,
      sunSign: kundali.sunSign,
      nakshatra: kundali.nakshatra,
      nakshatraPada: kundali.nakshatraPada,
      planets: [
        ...kundali.planets.where((p) => p.planet != 'Mars'),
        const PlanetPosition(
          planet: 'Mars',
          sign: 'Aries',
          house: 8,
          longitude: 1,
          degree: 1,
        ),
      ],
    );

    expect(const CalculateNavamsa()(withVargottama).vargottama, ['Mars']);
  });

  testWidgets('South Indian chart places signs in fixed cells', (
    tester,
  ) async {
    final navamsa = const CalculateNavamsa()(_sampleKundali());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: SouthIndianChart(chart: navamsa.chart),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.textContaining(l10n.chartLagnaMark), findsOneWidget);

    // Pisces is fixed in the top-left cell, Virgo in the bottom-right.
    final pisces = tester.getTopLeft(find.text(l10n.pisces));
    final virgo = tester.getTopLeft(find.text(l10n.virgo));
    expect(pisces.dx, lessThan(100));
    expect(pisces.dy, lessThan(100));
    expect(virgo.dx, greaterThan(300));
    expect(virgo.dy, greaterThan(300));
    expect(tester.takeException(), isNull);
  });
}
