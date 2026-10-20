import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/auth/data/auth_service.dart';
import 'package:rv_astro_vastu/features/auth/presentation/pages/account_page.dart';
import 'package:rv_astro_vastu/features/auth/presentation/providers/auth_provider.dart';
import 'package:rv_astro_vastu/features/membership/domain/membership.dart';
import 'package:rv_astro_vastu/features/membership/presentation/providers/membership_provider.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

import '../membership/fake_purchases_service.dart';

class _FakeAuth extends AuthService {
  String? signedInEmail;
  final List<String> sent = [];

  @override
  bool get isAvailable => true;

  @override
  bool get isAnonymous => signedInEmail == null;

  @override
  String? get email => signedInEmail;

  @override
  Future<void> sendEmailCode(String email) async => sent.add(email);

  @override
  Future<void> verifyEmailCode(String email, String code) async {
    if (code != '123456') throw StateError('bad code');
    signedInEmail = email;
  }
}

Future<AppLocalizations> _pump(
  WidgetTester tester, {
  required AuthService auth,
  required FakePurchasesService store,
}) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        authUserIdProvider.overrideWithValue('guest'),
        purchasesServiceProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: [Locale('en')],
        home: AccountPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  testWidgets('signs in with an emailed code', (tester) async {
    final auth = _FakeAuth();
    final l10n = await _pump(tester, auth: auth, store: FakePurchasesService());

    expect(find.text(l10n.accountFreePlan), findsOneWidget);
    expect(find.text(l10n.accountSeePremium), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'not-an-email');
    await tester.tap(find.text(l10n.accountSendCode));
    await tester.pump();
    expect(find.text(l10n.accountInvalidEmail), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ritu@example.com');
    await tester.tap(find.text(l10n.accountSendCode));
    await tester.pumpAndSettle();
    expect(auth.sent, ['ritu@example.com']);
    expect(find.text(l10n.accountCodeSent('ritu@example.com')), findsOneWidget);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text(l10n.accountVerify));
    await tester.pumpAndSettle();
    expect(find.text(l10n.accountInvalidCode), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text(l10n.accountVerify));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.accountSignedInAs('ritu@example.com')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows Premium status and add-ons', (tester) async {
    final l10n = await _pump(
      tester,
      auth: _FakeAuth()..signedInEmail = 'ritu@example.com',
      store: FakePurchasesService(
        state: MembershipState(
          premium: true,
          willRenew: true,
          premiumUntil: DateTime.utc(2027, 10, 20, 12),
        ),
      ),
    );

    expect(find.text(l10n.accountPremiumPlan), findsOneWidget);
    expect(find.textContaining('2027'), findsOneWidget);
    expect(find.text(l10n.accountSeePremium), findsNothing);
  });

  testWidgets('a free account lists its add-ons', (tester) async {
    final l10n = await _pump(
      tester,
      auth: _FakeAuth(),
      store: FakePurchasesService(
        state: const MembershipState(addOns: {AddOn.kundliPdf}),
      ),
    );

    expect(find.text(l10n.accountOwnedAddOns), findsOneWidget);
    expect(
      find.text('• ${l10n.premiumFeatureName('kundliPdf')}'),
      findsOneWidget,
    );
  });
}
