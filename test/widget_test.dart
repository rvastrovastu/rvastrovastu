import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rv_astro_vastu/app/app.dart';

void main() {
  testWidgets('RV Astro Vastu splash starts successfully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: RvAstroVastuApp()));

    await tester.pump();

    // Splash should render the localized application name.
    expect(find.text('RV Astro Vastu'), findsOneWidget);

    // Splash subtitle may now be localized through ARB.
    expect(find.text('Welcome to RV Astro Vastu'), findsOneWidget);

    // Advance past splash navigation timer.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });
}
