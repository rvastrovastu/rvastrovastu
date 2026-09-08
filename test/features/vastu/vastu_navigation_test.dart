import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/app/router.dart';
import 'package:rv_astro_vastu/features/vastu/presentation/pages/vastu_entry_analysis_page.dart';
import 'package:rv_astro_vastu/features/vastu/presentation/pages/vastu_tip_page.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'Vastu tip page navigates to entrance analysis through the real router',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            routerConfig: AppRouter.router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      AppRouter.router.go('/vastu');
      await tester.pumpAndSettle();

      expect(find.byType(VastuTipPage), findsOneWidget);
      expect(find.text('Entrance Analysis'), findsOneWidget);

      await tester.tap(find.text('Entrance Analysis'));
      await tester.pumpAndSettle();

      expect(
        find.byType(VastuEntryAnalysisPage),
        findsOneWidget,
      );

      expect(find.text('W4'), findsWidgets);
      expect(find.text('Pushpadanta'), findsOneWidget);
      expect(find.text('Favorable'), findsWidgets);
    },
  );

  testWidgets(
    'Vastu entrance route resolves directly through the real router',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            routerConfig: AppRouter.router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      AppRouter.router.go('/vastu/entrance');
      await tester.pumpAndSettle();

      expect(
        find.byType(VastuEntryAnalysisPage),
        findsOneWidget,
      );

      expect(find.text('W4'), findsWidgets);
      expect(find.text('Pushpadanta'), findsOneWidget);
    },
  );
}
