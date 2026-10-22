import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/gochar/domain/entities/transit.dart';
import 'package:rv_astro_vastu/features/rashifal/data/sky_repository.dart';
import 'package:rv_astro_vastu/features/rashifal/domain/rashifal.dart';
import 'package:rv_astro_vastu/features/rashifal/presentation/rashifal_page.dart';
import 'package:rv_astro_vastu/features/rashifal/presentation/rashifal_providers.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

/// Every planet in [sign] except those overridden.
SkySnapshot _sky(int sign, [Map<String, int> overrides = const {}]) =>
    SkySnapshot(DateTime.utc(2026, 10, 21), {
      for (final p in const [
        'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', //
        'Venus', 'Saturn', 'Rahu', 'Ketu',
      ])
        p: overrides[p] ?? sign,
    });

class _FakeSky implements SkyRepository {
  @override
  Future<List<SkySnapshot>> snapshots(List<DateTime> utcMoments) async => [
    for (final m in utcMoments)
      SkySnapshot(m, {
        'Sun': 5, 'Moon': (m.day) % 12, 'Mars': 2, 'Mercury': 5, //
        'Jupiter': 3, 'Venus': 6, 'Saturn': 11, 'Rahu': 10, 'Ketu': 4,
      }),
  ];
}

void main() {
  const engine = RashifalEngine();

  test('the Moon in a good house lifts the day', () {
    // Aries reader: Moon in Gemini = 3rd house (favourable).
    final good = engine.daily(0, DateTime(2026, 10, 21), _sky(0, {'Moon': 2}));
    // Moon in Scorpio = 8th house (challenging).
    final hard = engine.daily(0, DateTime(2026, 10, 21), _sky(0, {'Moon': 7}));
    expect(good.moonHouse, 3);
    expect(hard.moonHouse, 8);
    expect(good.overall, greaterThan(hard.overall));
    expect(good.stars[LifeArea.health], greaterThan(hard.stars[LifeArea.health]!));
  });

  test('stars stay between 1 and 5', () {
    for (var sign = 0; sign < 12; sign++) {
      final r = engine.daily(sign, DateTime(2026, 10, 21), _sky(5));
      for (final s in [...r.stars.values, r.overall]) {
        expect(s, inInclusiveRange(1, 5));
      }
    }
  });

  test('lucky planet is the weekday lord when friendly, else the sign lord', () {
    // Wednesday 21 Oct 2026: Mercury's day.
    final wednesday = DateTime(2026, 10, 21);
    expect(wednesday.weekday, DateTime.wednesday);
    // Libra (Venus) is friends with Mercury → Mercury.
    expect(engine.daily(6, wednesday, _sky(0)).luckyPlanet, 'Mercury');
    // Aries (Mars) is not → Mars.
    expect(engine.daily(0, wednesday, _sky(0)).luckyPlanet, 'Mars');
  });

  test('weekly good days are the days the Moon is favourable', () {
    final monday = DateTime(2026, 10, 19);
    final days = [
      for (var i = 0; i < 7; i++)
        _sky(0, {'Moon': i}), // Aries reader: houses 1..7
    ];
    final r = engine.weekly(0, monday, days);
    // Favourable Moon houses from 1–7: 1, 3, 6, 7 → Mon, Wed, Sat, Sun.
    expect(r.goodDays.map((d) => d.weekday), [1, 3, 6, 7]);
    expect(r.to, DateTime(2026, 10, 25));
  });

  test('yearly reads slow planets and lists ingresses inside the year', () {
    PlanetSignPeriod p(TransitPlanet planet, int sign, DateTime s, DateTime e) =>
        PlanetSignPeriod(planet: planet, signIndex: sign, start: s, end: e);
    final y0 = DateTime.utc(2027), mid = DateTime.utc(2027, 6, 2);
    final y1 = DateTime.utc(2028);
    final r = engine.yearly(0, 2027, {
      TransitPlanet.jupiter: [
        p(TransitPlanet.jupiter, 3, y0, mid),
        p(TransitPlanet.jupiter, 4, mid, y1),
      ],
      TransitPlanet.saturn: [p(TransitPlanet.saturn, 0, y0, y1)],
      TransitPlanet.rahu: [p(TransitPlanet.rahu, 10, y0, y1)],
      TransitPlanet.ketu: [p(TransitPlanet.ketu, 4, y0, y1)],
    });
    expect(r.ingresses.single.planet, 'Jupiter');
    expect(r.ingresses.single.signIndex, 4);
    // Saturn over the Moon sign = Sade Sati peak.
    expect(r.sadeSatiHouse, 1);
    expect(r.notes.map((n) => n.planet), containsAll(['Jupiter', 'Saturn']));
  });

  testWidgets('the page shows areas, lucky details and switches period', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skyRepositoryProvider.overrideWithValue(_FakeSky()),
          userMoonSignProvider.overrideWith((ref) async => 4),
          rashifalTodayProvider.overrideWithValue(DateTime(2026, 10, 21)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: const RashifalPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.leo), findsWidgets);
    for (final area in LifeArea.values) {
      expect(find.text(l10n.rashifalArea(area.name)), findsOneWidget);
    }
    expect(find.textContaining('Lucky colour'), findsOneWidget);

    await tester.tap(find.text(l10n.rashifalPeriod('weekly')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lucky colour'), findsNothing);
    expect(find.textContaining('Best days'), findsOneWidget);
  });
}
