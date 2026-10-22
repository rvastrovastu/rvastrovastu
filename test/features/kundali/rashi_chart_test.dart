import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/planet_position.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/rashi_chart.dart';
import 'package:rv_astro_vastu/features/kundali/presentation/widgets/rashi_chart/rashi_chart_v2.dart';
import 'package:rv_astro_vastu/features/kundali/presentation/widgets/rashi_chart/south_indian_chart.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

const _signs = [
  'Leo', 'Virgo', 'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', //
  'Aquarius', 'Pisces', 'Aries', 'Taurus', 'Gemini', 'Cancer',
];

RashiChart _chart() => RashiChart(
  houses: [
    for (var h = 1; h <= 12; h++)
      RashiHouse(
        house: h,
        sign: _signs[h - 1],
        planets: [
          if (h == 1)
            const PlanetPosition(
              planet: 'Jupiter',
              sign: 'Leo',
              house: 1,
              longitude: 132.5,
              degree: 12.5,
              retrograde: true,
              nakshatra: 'Magha',
              nakshatraPada: 4,
            ),
          if (h == 10)
            const PlanetPosition(
              planet: 'Sun',
              sign: 'Taurus',
              house: 10,
              longitude: 48,
              degree: 18,
            ),
        ],
      ),
  ],
);

Future<AppLocalizations> _pump(WidgetTester tester, Widget chart) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: SingleChildScrollView(child: chart)),
    ),
  );
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  test('taps land in the right North Indian house', () {
    expect(northHouseAt(const Offset(0.5, 0.2)), 1);
    expect(northHouseAt(const Offset(0.25, 0.05)), 2);
    expect(northHouseAt(const Offset(0.05, 0.25)), 3);
    expect(northHouseAt(const Offset(0.2, 0.5)), 4);
    expect(northHouseAt(const Offset(0.05, 0.75)), 5);
    expect(northHouseAt(const Offset(0.25, 0.95)), 6);
    expect(northHouseAt(const Offset(0.5, 0.8)), 7);
    expect(northHouseAt(const Offset(0.75, 0.95)), 8);
    expect(northHouseAt(const Offset(0.95, 0.75)), 9);
    expect(northHouseAt(const Offset(0.8, 0.5)), 10);
    expect(northHouseAt(const Offset(0.95, 0.25)), 11);
    expect(northHouseAt(const Offset(0.75, 0.05)), 12);
  });

  testWidgets('North chart shows sign numbers and planets, tap for details', (
    tester,
  ) async {
    final l10n = await _pump(tester, RashiChartV2(chart: _chart()));

    expect(find.text(l10n.chartLagnaMark), findsOneWidget);
    expect(find.text('5'), findsOneWidget); // Leo in the Lagna
    expect(find.textContaining('Ju'), findsOneWidget);

    // House 1 sits in the top diamond.
    final box = tester.getRect(find.byType(AspectRatio));
    await tester.tapAt(box.topLeft + Offset(box.width * 0.5, box.height * 0.2));
    await tester.pumpAndSettle();

    expect(find.text(l10n.chartHouseTitle(1, l10n.leo)), findsOneWidget);
    expect(
      find.text('${l10n.jupiter} · ${l10n.retrograde}'),
      findsOneWidget,
    );
  });

  testWidgets('an empty house says so', (tester) async {
    final l10n = await _pump(tester, RashiChartV2(chart: _chart()));
    final box = tester.getRect(find.byType(AspectRatio));
    await tester.tapAt(box.topLeft + Offset(box.width * 0.5, box.height * 0.8));
    await tester.pumpAndSettle();
    expect(find.text(l10n.chartHouseEmpty), findsOneWidget);
  });

  testWidgets('South chart marks the Lagna sign', (tester) async {
    final l10n = await _pump(tester, SouthIndianChart(chart: _chart()));
    expect(find.text('${l10n.chartLagnaMark}: ${l10n.leo}'), findsOneWidget);
    expect(find.textContaining('Su'), findsOneWidget);
  });
}
