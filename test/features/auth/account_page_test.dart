import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  int deletions = 0;
  bool failDelete = false;

  @override
  Future<void> deleteAccount() async {
    if (failDelete) throw StateError('offline');
    deletions++;
    signedInEmail = null;
  }
}

/// Pumps the account page inside a router so deletion can navigate.
Future<AppLocalizations> _pumpRouted(
  WidgetTester tester, {
  required _FakeAuth auth,
  required FakePurchasesService store,
}) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/account',
    routes: [
      GoRoute(path: '/account', builder: (_, _) => const AccountPage()),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const Scaffold(body: Text('onboarding')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        authUserIdProvider.overrideWithValue('guest'),
        purchasesServiceProvider.overrideWithValue(store),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
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

  group('delete account', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'birth_profiles': '[{"id":"1","name":"Ritu"}]',
        'active_birth_profile_id': '1',
      });
    });

    Future<void> openDialog(WidgetTester tester, AppLocalizations l10n) async {
      final button = find.text(l10n.accountDeleteButton);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(l10n.accountDeleteTitle), findsOneWidget);
    }

    testWidgets('cancel keeps everything', (tester) async {
      final auth = _FakeAuth()..signedInEmail = 'ritu@example.com';
      final l10n = await _pumpRouted(
        tester,
        auth: auth,
        store: FakePurchasesService(),
      );

      await openDialog(tester, l10n);
      expect(find.text(l10n.accountDeleteSubscriptionWarning), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(auth.deletions, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('birth_profiles'), isNotNull);
    });

    testWidgets('deletes the account and local profiles', (tester) async {
      final auth = _FakeAuth()..signedInEmail = 'ritu@example.com';
      final l10n = await _pumpRouted(
        tester,
        auth: auth,
        store: FakePurchasesService(),
      );

      await openDialog(tester, l10n);
      await tester.tap(find.text(l10n.accountDeleteConfirm));
      await tester.pumpAndSettle();

      expect(auth.deletions, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('birth_profiles'), isNull);
      expect(prefs.getString('active_birth_profile_id'), isNull);
      expect(find.text('onboarding'), findsOneWidget);
      expect(find.text(l10n.accountDeleted), findsOneWidget);
    });

    testWidgets('warns that a renewing subscription keeps billing', (
      tester,
    ) async {
      final l10n = await _pumpRouted(
        tester,
        auth: _FakeAuth()..signedInEmail = 'ritu@example.com',
        store: FakePurchasesService(
          state: MembershipState(
            premium: true,
            willRenew: true,
            premiumUntil: DateTime.utc(2027, 10, 20),
          ),
        ),
      );

      await openDialog(tester, l10n);
      expect(find.text(l10n.accountDeleteSubscriptionWarning), findsOneWidget);
    });

    testWidgets('shows an error and keeps data when deletion fails', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..signedInEmail = 'ritu@example.com'
        ..failDelete = true;
      final l10n = await _pumpRouted(
        tester,
        auth: auth,
        store: FakePurchasesService(),
      );

      await openDialog(tester, l10n);
      await tester.tap(find.text(l10n.accountDeleteConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountDeleteFailed), findsOneWidget);
      expect(find.text('onboarding'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('birth_profiles'), isNotNull);
    });
  });
}
