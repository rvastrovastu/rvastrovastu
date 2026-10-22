import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/festivals/domain/entities/calendar_observance.dart';
import 'package:rv_astro_vastu/features/festivals/guide/data/puja_guide_repository.dart';
import 'package:rv_astro_vastu/features/festivals/guide/domain/puja_timing.dart';
import 'package:rv_astro_vastu/features/festivals/guide/presentation/pages/puja_guide_page.dart';
import 'package:rv_astro_vastu/features/festivals/guide/presentation/puja_guide_providers.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';
import 'package:timezone/data/latest.dart' as tz;

import '../../membership/premium_test_helper.dart';
import 'puja_guide_test_bundle.dart';

final _date = DateTime(2026, 11, 8);

Future<AppLocalizations> _pump(
  WidgetTester tester, {
  required Override membership,
  ObservanceId id = ObservanceId.diwali,
}) async {
  tester.view.physicalSize = const Size(430, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        membership,
        pujaGuideRepositoryProvider.overrideWithValue(
          PujaGuideRepository(FileAssetBundle()),
        ),
        pujaTimingProvider((id: id, date: _date)).overrideWith(
          (ref) async => PujaTiming(
            rule: PujaTimeRule.pradosh,
            timezone: 'UTC',
            window: TimeWindow(
              DateTime.utc(2026, 11, 8, 17, 30),
              DateTime.utc(2026, 11, 8, 19, 54),
            ),
            avoid: [
              (
                'rahuKaal',
                TimeWindow(
                  DateTime.utc(2026, 11, 8, 16, 30),
                  DateTime.utc(2026, 11, 8, 18),
                ),
              ),
            ],
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: PujaGuidePage(id: id, date: _date),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  setUpAll(tz.initializeTimeZones);

  testWidgets('free users get the overview, samagri and aarti', (
    tester,
  ) async {
    final l10n = await _pump(tester, membership: freeOverride);

    expect(find.text(l10n.pujaGuideSection('about')), findsOneWidget);
    expect(find.text(l10n.pujaGuideSection('samagri')), findsOneWidget);
    expect(find.text(l10n.pujaGuideSamagriProgress(0, 8)), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    expect(find.text(l10n.pujaGuideSamagriProgress(1, 8)), findsOneWidget);

    await tester.tap(find.text(l10n.pujaGuideTab('aarti')));
    await tester.pumpAndSettle();
    expect(find.textContaining('जय गणेश'), findsWidgets);

    await tester.tap(find.text(l10n.pujaGuideScript('latin')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jai Ganesh Deva'), findsWidgets);
  });

  testWidgets('the vidhi is Premium, with a first step as a preview', (
    tester,
  ) async {
    final l10n = await _pump(tester, membership: freeOverride);

    await tester.tap(find.text(l10n.pujaGuideTab('vidhi')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.premiumFeatureName('pujaVidhi')), findsOneWidget);
    expect(find.text(l10n.pujaGuideSection('mantras')), findsNothing);
    expect(find.text(l10n.pujaGuideSection('timing')), findsNothing);
  });

  testWidgets('Premium shows the timing, steps, mantras and katha', (
    tester,
  ) async {
    final l10n = await _pump(tester, membership: premiumOverride);

    await tester.tap(find.text(l10n.pujaGuideTab('vidhi')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.pujaGuideSection('timing')), findsOneWidget);
    expect(find.text(l10n.pujaGuideWindow('pradosh')), findsOneWidget);
    expect(find.byKey(const ValueKey('pujaWindow')), findsOneWidget);
    // Rahu Kaal ends inside the window.
    expect(
      find.text(l10n.pujaGuideClash(l10n.pujaGuidePeriod('rahuKaal'))),
      findsOneWidget,
    );
    expect(find.text(l10n.pujaGuideSection('mantras')), findsOneWidget);
    expect(find.textContaining('Om Gam Ganapataye Namah'), findsOneWidget);
    expect(find.text(l10n.pujaGuideSection('story')), findsOneWidget);
    expect(find.text(l10n.premiumFeatureName('pujaVidhi')), findsNothing);
  });

  testWidgets('an observance without an aarti says so', (tester) async {
    final l10n = await _pump(
      tester,
      membership: freeOverride,
      id: ObservanceId.amavasya,
    );

    await tester.tap(find.text(l10n.pujaGuideTab('aarti')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.pujaGuideNoAarti), findsOneWidget);
  });
}
