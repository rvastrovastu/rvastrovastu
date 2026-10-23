import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rv_astro_vastu/features/home/presentation/widgets/app_drawer.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            drawer: const AppDrawer(),
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                child: const Text('Open menu'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/rashifal',
          builder: (context, state) =>
              const Scaffold(body: Text('Rashifal destination')),
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  testWidgets('menu lists features and opens them', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text(l10n.appName), findsOneWidget);
    expect(find.text(l10n.menuSectionDaily.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.rashifalTitle), findsOneWidget);
    // Without Supabase there is no account to show.
    expect(find.text(l10n.menuGuestTitle), findsNothing);

    await tester.tap(find.text(l10n.rashifalTitle));
    await tester.pumpAndSettle();

    expect(find.text('Rashifal destination'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
  });
}
