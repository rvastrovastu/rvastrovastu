import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rv_astro_vastu/app/app.dart';

void main() {
  testWidgets('RV Astro Vastu splash starts successfully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: RvAstroVastuApp()));

    await tester.pump();

    expect(find.text('RV Astro Vastu'), findsOneWidget);

    expect(find.text('Discover your cosmic journey'), findsOneWidget);

    // Advance past the splash navigation timer.
    await tester.pump(const Duration(seconds: 2));

    await tester.pump();
  });
}
