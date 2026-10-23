import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rv_astro_vastu/features/home/presentation/widgets/quick_actions.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

void main() {
  late GoRouter router;

  setUp(() {
    GoRoute destination(String path) => GoRoute(
      path: path,
      builder: (context, state) => Scaffold(body: Text('$path destination')),
    );

    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            drawer: Drawer(child: Text('Menu drawer')),
            body: Center(child: QuickActions()),
          ),
        ),
        for (final path in [
          '/ask',
          '/rashifal',
          '/muhurat',
          '/compatibility',
          '/dosha',
          '/remedies',
        ])
          destination(path),
      ],
    );
  });

  tearDown(() => router.dispose());

  Future<AppLocalizations> pumpQuickActions(WidgetTester tester) async {
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

  testWidgets('shows the shortcuts and an All features tile', (tester) async {
    final l10n = await pumpQuickActions(tester);

    for (final title in [
      l10n.aiTitle,
      l10n.rashifalTitle,
      l10n.muhuratPlannerTitle,
      l10n.compatTitle,
      l10n.doshaCheckTitle,
      l10n.remediesTitle,
      l10n.homeAllFeatures,
    ]) {
      final tile = find.text(title);
      await tester.ensureVisible(tile);
      expect(tile, findsOneWidget);
    }
  });

  final routes = <String, String Function(AppLocalizations)>{
    '/ask': (l) => l.aiTitle,
    '/rashifal': (l) => l.rashifalTitle,
    '/muhurat': (l) => l.muhuratPlannerTitle,
    '/compatibility': (l) => l.compatTitle,
    '/dosha': (l) => l.doshaCheckTitle,
    '/remedies': (l) => l.remediesTitle,
  };

  for (final MapEntry(key: path, value: title) in routes.entries) {
    testWidgets('opens $path', (tester) async {
      final l10n = await pumpQuickActions(tester);

      final tile = find.text(title(l10n));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.text('$path destination'), findsOneWidget);
    });
  }

  testWidgets('All features opens the menu', (tester) async {
    final l10n = await pumpQuickActions(tester);

    final tile = find.text(l10n.homeAllFeatures);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.text('Menu drawer'), findsOneWidget);
  });
}
