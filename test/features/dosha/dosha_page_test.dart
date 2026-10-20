import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/dosha/domain/usecases/calculate_sade_sati.dart';
import 'package:rv_astro_vastu/features/dosha/domain/usecases/check_kaal_sarp_dosha.dart';
import 'package:rv_astro_vastu/features/dosha/domain/usecases/check_manglik_dosha.dart';
import 'package:rv_astro_vastu/features/dosha/presentation/pages/dosha_page.dart';
import 'package:rv_astro_vastu/features/dosha/presentation/providers/dosha_provider.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

import 'package:rv_astro_vastu/features/astrology/presentation/utils/astrology_localization.dart';

import '../membership/premium_test_helper.dart';

import 'dosha_test_helpers.dart';

void main() {
  DoshaReport buildReport() {
    // Leo lagna with an Aquarius Moon; Saturn data puts this Moon sign in
    // the setting phase of Sade Sati in October 2026.
    final kundali = kundaliFrom(
      ascendant: inSign('Leo', 1),
      longitudes: {
        'Rahu': inSign('Aries', 2),
        'Sun': inSign('Taurus'),
        'Moon': inSign('Aquarius', 1),
        'Mars': inSign('Gemini'),
        'Mercury': inSign('Taurus', 20),
        'Jupiter': inSign('Cancer'),
        'Venus': inSign('Gemini', 25),
        'Saturn': inSign('Virgo'),
      },
    );

    return DoshaReport(
      kundali: kundali,
      manglik: const CheckManglikDosha()(kundali),
      kaalSarp: const CheckKaalSarpDosha()(kundali),
      sadeSati: const CalculateSadeSati()(
        moonSign: 'Aquarius',
        saturnPeriods: saturnPeriods,
        referenceDate: DateTime.utc(2026, 10, 16),
      ),
    );
  }

  Future<AppLocalizations> pumpPage(
    WidgetTester tester,
    Future<DoshaReport?> Function() report, {
    bool premium = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premium ? premiumOverride : freeOverride,
          doshaReportProvider.overrideWith((ref) => report()),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en')],
          home: DoshaPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.delegate.load(const Locale('en'));
  }

  testWidgets('shows all three dosha cards for a profile', (tester) async {
    final l10n = await pumpPage(tester, () async => buildReport());

    expect(find.text(l10n.manglikTitle), findsOneWidget);
    expect(find.text(l10n.kaalSarpTitle), findsOneWidget);

    await tester.scrollUntilVisible(find.text(l10n.sadeSatiTitle), 200);
    expect(find.text(l10n.sadeSatiTitle), findsOneWidget);
    expect(
      find.text(l10n.sadeSatiActive(l10n.sadeSatiPhase('setting'))),
      findsOneWidget,
    );
  });

  testWidgets('asks for a birth profile when none is active', (tester) async {
    final l10n = await pumpPage(tester, () async => null);

    expect(find.text(l10n.birthProfileRequired), findsOneWidget);
    expect(find.text(l10n.createBirthProfile), findsOneWidget);
  });

  testWidgets('free accounts see statuses but not the details', (
    tester,
  ) async {
    final l10n = await pumpPage(
      tester,
      () async => buildReport(),
      premium: false,
    );

    // Manglik stays free and keeps its details.
    expect(find.text(l10n.manglikTitle), findsOneWidget);
    expect(find.textContaining(l10n.rashiName('Gemini')), findsWidgets);

    await tester.scrollUntilVisible(find.text(l10n.sadeSatiTitle), 200);
    expect(find.text(l10n.doshaStatus('active')), findsOneWidget);
    expect(
      find.text(l10n.sadeSatiActive(l10n.sadeSatiPhase('setting'))),
      findsNothing,
    );
    expect(find.text(l10n.premiumUnlockDetails), findsNWidgets(2));
  });
}
