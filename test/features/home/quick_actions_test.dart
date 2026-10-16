import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rv_astro_vastu/features/home/presentation/widgets/quick_actions.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: QuickActions())),
        ),
        GoRoute(
          path: '/kundali',
          builder: (context, state) =>
              const Scaffold(body: Text('Kundali destination')),
        ),
        GoRoute(
          path: '/saved-profiles',
          builder: (context, state) =>
              const Scaffold(body: Text('Saved profiles destination')),
        ),
        GoRoute(
          path: '/compatibility',
          builder: (context, state) =>
              const Scaffold(body: Text('Compatibility destination')),
        ),
        GoRoute(
          path: '/muhurat',
          builder: (context, state) =>
              const Scaffold(body: Text('Muhurat destination')),
        ),
      ],
    );
  });

  tearDown(() {
    router.dispose();
  });

  Future<void> pumpQuickActions(WidgetTester tester) async {
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
  }

  testWidgets('shows both Quick Actions', (tester) async {
    await pumpQuickActions(tester);

    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month), findsOneWidget);
    expect(find.byIcon(Icons.favorite_outline), findsOneWidget);
    expect(find.text('Marriage Compatibility'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(4));
  });

  testWidgets('Kundali action opens the Kundali route', (tester) async {
    await pumpQuickActions(tester);

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    expect(find.text('Kundali destination'), findsOneWidget);
  });

  testWidgets('Birth Profile action opens saved profiles', (tester) async {
    await pumpQuickActions(tester);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text('Saved profiles destination'), findsOneWidget);
  });

  testWidgets('Compatibility action opens the Compatibility route', (
    tester,
  ) async {
    await pumpQuickActions(tester);

    final action = find.text('Marriage Compatibility');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('Compatibility destination'), findsOneWidget);
  });

  testWidgets('Muhurat action opens the Muhurat route', (tester) async {
    await pumpQuickActions(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final action = find.text(l10n.muhuratPlannerTitle);

    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('Muhurat destination'), findsOneWidget);
  });
}
