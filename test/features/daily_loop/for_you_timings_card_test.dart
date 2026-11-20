import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/daily_loop/domain/personal_muhurat.dart';
import 'package:rv_astro_vastu/features/daily_loop/presentation/daily_loop_providers.dart';
import 'package:rv_astro_vastu/features/daily_loop/presentation/widgets/personal_muhurat_body.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/day_divisions.dart';
import 'package:rv_astro_vastu/features/your_day/domain/day_strength.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';
import 'package:timezone/data/latest.dart' as tzdata;

Future<AppLocalizations> _pump(
  WidgetTester tester,
  List<MuhuratWindow> windows,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        personalMuhuratProvider.overrideWith(
          (ref) async => (windows: windows, timezone: 'Etc/UTC'),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: ForYouTimingsCard(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('every purpose shows what it is for', (tester) async {
    final l10n = await _pump(tester, const []);

    expect(find.text(l10n.forYouTimingsTitle), findsOneWidget);
    expect(find.text(l10n.forYouAskPurpose), findsOneWidget);
    for (final p in MuhuratPurpose.values) {
      expect(find.text(l10n.muhuratPurpose(p.name)), findsOneWidget);
      expect(find.text(l10n.muhuratPurposeHint(p.name)), findsOneWidget);
    }
    expect(find.text(l10n.muhuratForYouNone), findsOneWidget);
  });

  testWidgets('picking a purpose changes the heading', (tester) async {
    final l10n = await _pump(tester, const []);
    final travel = l10n.muhuratPurpose(MuhuratPurpose.travel.name);

    await tester.tap(find.byKey(const ValueKey('purpose_travel')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.forYouBestTimesFor(travel)), findsOneWidget);
  });

  testWidgets('a window says when, why and how it suits your star', (
    tester,
  ) async {
    final l10n = await _pump(tester, [
      MuhuratWindow(
        start: DateTime.utc(2026, 10, 18, 9),
        end: DateTime.utc(2026, 10, 18, 10, 30),
        choghadiya: Choghadiya.labh,
        hora: 'Jupiter',
        tara: Tara.mitra,
        score: 9,
      ),
    ]);

    expect(find.text('9:00 AM – 10:30 AM'), findsOneWidget);
    expect(find.text(l10n.muhuratForYouBest), findsOneWidget);
    expect(
      find.text(
        l10n.muhuratForYouReason(l10n.choghadiyaName('labh'), l10n.jupiter),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.muhuratForYouStar('good')), findsOneWidget);
  });
}
