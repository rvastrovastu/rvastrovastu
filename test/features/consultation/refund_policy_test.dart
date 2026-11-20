import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/consultation/presentation/widgets/refund_policy.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

void main() {
  testWidgets('the refund link opens the cancellation rules', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: [Locale('en')],
        home: Scaffold(body: Center(child: RefundPolicyLink())),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const ValueKey('refundPolicyLink')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.consultRefundCancel), findsOneWidget);
    expect(find.text(l10n.consultRefundOurSide), findsOneWidget);
    expect(find.text(l10n.consultRefundNoShow), findsOneWidget);
    expect(find.text(l10n.consultRefundHow), findsOneWidget);
    expect(find.text(l10n.consultRefundTerms), findsOneWidget);
  });
}
