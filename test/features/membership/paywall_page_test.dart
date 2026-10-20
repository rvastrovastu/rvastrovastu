import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/auth/presentation/providers/auth_provider.dart';
import 'package:rv_astro_vastu/features/membership/domain/membership.dart';
import 'package:rv_astro_vastu/features/membership/presentation/pages/paywall_page.dart';
import 'package:rv_astro_vastu/features/membership/presentation/providers/membership_provider.dart';
import 'package:rv_astro_vastu/features/membership/presentation/widgets/premium_gate.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

import 'fake_purchases_service.dart';

Future<AppLocalizations> _pump(
  WidgetTester tester,
  FakePurchasesService service,
  Widget home,
) async {
  tester.view.physicalSize = const Size(430, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        purchasesServiceProvider.overrideWithValue(service),
        authUserIdProvider.overrideWithValue('user-1'),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  testWidgets('yearly is pre-selected with its saving and free trial', (
    tester,
  ) async {
    final service = FakePurchasesService(
      planOffers: FakePurchasesService.usPlans(),
      addOnOffers: FakePurchasesService.usAddOns,
    );
    final l10n = await _pump(
      tester,
      service,
      const PaywallPage(highlight: PremiumFeature.remedies),
    );

    expect(service.userId, 'user-1');
    expect(
      find.text(
        l10n.premiumFeatureLocked(l10n.premiumFeatureName('remedies')),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.premiumSave('16')), findsOneWidget);
    expect(find.text(l10n.premiumTrial('7')), findsOneWidget);
    expect(find.text(l10n.premiumStartTrial('7')), findsOneWidget);
    expect(find.text(r'$2.99'), findsOneWidget);

    // Monthly has no trial, so the button reads Continue.
    await tester.tap(find.text(l10n.premiumPlanName('monthly')));
    await tester.pump();
    expect(find.text(l10n.premiumContinue), findsOneWidget);

    await tester.tap(find.text(l10n.premiumContinue));
    await tester.pumpAndSettle();
    expect(service.bought, ['monthly']);
    expect(find.text(l10n.premiumActive), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('buying an add-on marks it owned', (tester) async {
    final service = FakePurchasesService(
      planOffers: FakePurchasesService.usPlans(trialDays: null),
      addOnOffers: FakePurchasesService.usAddOns,
    );
    final l10n = await _pump(tester, service, const PaywallPage());

    expect(find.text(l10n.premiumContinue), findsOneWidget);
    await tester.tap(find.text(r'$2.99'));
    await tester.pumpAndSettle();

    expect(service.bought, ['k']);
    expect(find.text(l10n.premiumOwned), findsOneWidget);
    expect(find.text(r'$1.99'), findsOneWidget);
  });

  testWidgets('PremiumGate shows the lock to free users', (tester) async {
    final l10n = await _pump(
      tester,
      FakePurchasesService(),
      const Scaffold(
        body: PremiumGate(
          feature: PremiumFeature.transits,
          child: Text('secret chart'),
        ),
      ),
    );
    expect(find.text('secret chart'), findsNothing);
    expect(find.text(l10n.premiumUnlock), findsOneWidget);
    expect(find.text(l10n.premiumFeatureName('transits')), findsOneWidget);
  });

  testWidgets('PremiumGate shows the content to members', (tester) async {
    await _pump(
      tester,
      FakePurchasesService(state: const MembershipState(premium: true)),
      const Scaffold(
        body: PremiumGate(
          feature: PremiumFeature.transits,
          child: Text('secret chart'),
        ),
      ),
    );
    expect(find.text('secret chart'), findsOneWidget);
  });
}
