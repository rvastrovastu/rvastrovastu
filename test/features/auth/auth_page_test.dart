import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rv_astro_vastu/features/auth/presentation/pages/auth_page.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/auth',
      routes: [
        GoRoute(path: '/auth', builder: (context, state) => const AuthPage()),
        GoRoute(
          path: '/account',
          builder: (context, state) => Scaffold(
            body: Text(
              'Account mode=${state.uri.queryParameters['mode']} '
              'next=${state.uri.queryParameters['next']}',
            ),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Home')),
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
    return AppLocalizations.delegate.load(const Locale('en'));
  }

  testWidgets('offers create account, sign in and guest', (tester) async {
    final l10n = await pump(tester);

    expect(find.text(l10n.authCreateAccount), findsOneWidget);
    expect(find.text(l10n.authSignIn), findsOneWidget);
    expect(find.text(l10n.authContinueGuest), findsOneWidget);
  });

  testWidgets('create account opens the account page in create mode', (
    tester,
  ) async {
    final l10n = await pump(tester);

    await tester.tap(find.text(l10n.authCreateAccount));
    await tester.pumpAndSettle();

    expect(find.text('Account mode=create next=/home'), findsOneWidget);
  });

  testWidgets('sign in opens the account page', (tester) async {
    final l10n = await pump(tester);

    await tester.tap(find.text(l10n.authSignIn));
    await tester.pumpAndSettle();

    expect(find.text('Account mode=null next=/home'), findsOneWidget);
  });

  testWidgets('guest goes straight home', (tester) async {
    final l10n = await pump(tester);

    await tester.tap(find.text(l10n.authContinueGuest));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });
}
