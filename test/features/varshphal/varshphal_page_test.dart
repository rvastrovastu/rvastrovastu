import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/varshphal/varshphal.dart';
import 'package:rv_astro_vastu/features/varshphal/varshphal_page.dart';
import 'package:rv_astro_vastu/features/varshphal/varshphal_providers.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

import '../dosha/dosha_test_helpers.dart';
import '../membership/premium_test_helper.dart';

final _year = Varshphal(
  completedYears: 35,
  praveshUtc: DateTime.utc(2026, 8, 14, 3),
  praveshLocal: DateTime(2026, 8, 14, 8, 30),
  natalLagna: 4, // Leo
  chart: kundaliFrom(
    ascendant: inSign('Taurus', 5),
    longitudes: {
      'Sun': inSign('Cancer', 28),
      'Moon': inSign('Aries', 3),
      'Mars': inSign('Gemini', 10),
      'Mercury': inSign('Leo', 2),
      'Jupiter': inSign('Cancer', 12),
      'Venus': inSign('Virgo', 20),
      'Saturn': inSign('Pisces', 15),
      'Rahu': inSign('Aquarius', 22),
    },
  ),
);

Future<void> _pump(WidgetTester tester, Override membership) async {
  tester.view.physicalSize = const Size(430, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        membership,
        currentVarshaProvider.overrideWithValue(35),
        varshphalProvider.overrideWith((ref, years) async => _year),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: [Locale('en')],
        home: VarshphalPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('Muntha of the sample year', () {
    // Leo + 35 years → Cancer, the 3rd from a Taurus year Lagna.
    expect(_year.munthaSign, 3);
    expect(_year.munthaHouse, 3);
    expect(_year.tone, MunthaTone.good);
  });

  testWidgets('free: Muntha theme is shown, the year chart is locked', (
    tester,
  ) async {
    await _pump(tester, freeOverride);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.varshphalAge(36)), findsOneWidget);
    expect(
      find.text(l10n.varshphalTheme(l10n.gocharHouseTheme('h3'))),
      findsOneWidget,
    );
    expect(find.text(l10n.premiumFeatureName('varshphal')), findsOneWidget);
    expect(find.byKey(const ValueKey('varshphalPdf')), findsNothing);
  });

  testWidgets('Premium: year chart, planets and the PDF button', (
    tester,
  ) async {
    await _pump(tester, premiumOverride);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.varshphalChart), findsOneWidget);
    expect(find.text(l10n.varshphalPlanets), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('varshphalPdf')),
      300,
    );
    expect(find.byKey(const ValueKey('varshphalPdf')), findsOneWidget);
  });
}
