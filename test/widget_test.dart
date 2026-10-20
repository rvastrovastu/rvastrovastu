import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rv_astro_vastu/app/app.dart';

void main() {
  testWidgets('RV Astro Vastu splash starts successfully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: RvAstroVastuApp()));

    await tester.pump();

    // Verify that the splash renders text.
    expect(find.byType(Text), findsWidgets);

    // Advance past splash navigation timer.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });
}
