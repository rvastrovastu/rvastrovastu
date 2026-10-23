import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rv_astro_vastu/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingPage(),
        ),
        // Without Supabase (as in tests) onboarding finishes at /home.
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) => const Scaffold(body: Text('Auth')),
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  Future<AppLocalizations> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.delegate.load(const Locale('en'));
  }

  testWidgets('Next walks through all five feature pages', (tester) async {
    final l10n = await pump(tester);

    final titles = [
      l10n.onbKundliTitle,
      l10n.onbDailyTitle,
      l10n.onbVastuTitle,
      l10n.onbFestivalsTitle,
      l10n.onbAiTitle,
    ];
    for (final (index, title) in titles.indexed) {
      expect(find.text(title), findsOneWidget);
      if (index < titles.length - 1) {
        expect(find.text(l10n.onbNext), findsOneWidget);
        await tester.tap(find.text(l10n.onbNext));
        await tester.pumpAndSettle();
      }
    }

    expect(find.text(l10n.onbBegin), findsOneWidget);
    await tester.tap(find.text(l10n.onbBegin));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Skip leaves the tour from the first page', (tester) async {
    final l10n = await pump(tester);

    await tester.tap(find.text(l10n.onbSkip));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });
}
