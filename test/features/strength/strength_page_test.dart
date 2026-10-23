import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/astrology/presentation/providers/astrology_provider.dart';
import 'package:rv_astro_vastu/features/strength/strength_page.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

import '../dosha/dosha_test_helpers.dart';
import '../membership/premium_test_helper.dart';

Future<void> _pump(WidgetTester tester, Override membership) async {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final kundali = kundaliFrom(
    ascendant: inSign('Virgo', 2.92),
    longitudes: {
      'Sun': 236.53,
      'Moon': 139.01,
      'Mars': 198.55,
      'Mercury': 230.70,
      'Jupiter': 356.09,
      'Venus': 264.59,
      'Saturn': 239.52,
      'Rahu': 334.50,
    },
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        membership,
        kundaliProvider.overrideWith((ref) async => kundali),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: [Locale('en')],
        home: StrengthPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Premium shows Sarvashtakavarga and planet strength', (
    tester,
  ) async {
    await _pump(tester, premiumOverride);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.savTitle), findsOneWidget);
    for (var h = 1; h <= 12; h++) {
      expect(find.byKey(ValueKey('sav-house-$h')), findsOneWidget);
    }

    await tester.tap(find.text(l10n.strengthTab('shadbala')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('strength-Sun')), findsOneWidget);
    expect(find.byKey(const ValueKey('strength-Saturn')), findsOneWidget);
  });

  testWidgets('free accounts see the Premium lock', (tester) async {
    await _pump(tester, freeOverride);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.premiumFeatureName('strength')), findsOneWidget);
    expect(find.text(l10n.savTitle), findsNothing);
  });
}
