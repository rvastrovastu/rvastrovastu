import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rv_astro_vastu/app/app_shell.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

void main() {
  GoRouter buildRouter() {
    Widget page(String label) => Scaffold(body: Center(child: Text(label)));

    return GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            for (final path in [
              '/home',
              '/kundali',
              '/festivals',
              '/vastu',
              '/consult',
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (context, state) => page('$path page'),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  testWidgets('bottom tabs switch between the five areas', (tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text('/home page'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text(l10n.navCalendar));
    await tester.pumpAndSettle();
    expect(find.text('/festivals page'), findsOneWidget);

    await tester.tap(find.text(l10n.vastu));
    await tester.pumpAndSettle();
    expect(find.text('/vastu page'), findsOneWidget);

    await tester.tap(find.text(l10n.kundali));
    await tester.pumpAndSettle();
    expect(find.text('/kundali page'), findsOneWidget);

    await tester.tap(find.text(l10n.consultShort));
    await tester.pumpAndSettle();
    expect(find.text('/consult page'), findsOneWidget);

    await tester.tap(find.text(l10n.navToday));
    await tester.pumpAndSettle();
    expect(find.text('/home page'), findsOneWidget);
  });
}
