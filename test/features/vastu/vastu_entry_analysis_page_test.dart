import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_direction.dart';
import 'package:rv_astro_vastu/features/vastu/presentation/pages/vastu_entry_analysis_page.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

void main() {
  Widget buildTestApp() {
    return const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: VastuEntryAnalysisPage(),
      ),
    );
  }

  group('VastuEntryAnalysisPage', () {
    testWidgets(
      'calculates an unsupported pada safely for each cardinal direction',
      (tester) async {
        await tester.pumpWidget(buildTestApp());

        await tester.pumpAndSettle();

        expect(find.text('W4'), findsWidgets);

        final dropdown = find.byType(
          DropdownButtonFormField<VastuEntryDirection>,
        );
        expect(dropdown, findsOneWidget);

        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        await tester.tap(find.text('North').last);
        await tester.pumpAndSettle();

        expect(find.text('N4'), findsWidgets);
        expect(
          find.text('Assessment not available yet for this entrance pada.'),
          findsOneWidget,
        );

        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        await tester.tap(find.text('East').last);
        await tester.pumpAndSettle();

        expect(find.text('E4'), findsWidgets);
        expect(
          find.text('Assessment not available yet for this entrance pada.'),
          findsOneWidget,
        );

        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        await tester.tap(find.text('South').last);
        await tester.pumpAndSettle();

        expect(find.text('S4'), findsWidgets);
        expect(
          find.text('Assessment not available yet for this entrance pada.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders repository-supported W4 and W5 entrances', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.text('W4'), findsWidgets);
      expect(find.text('W5'), findsWidgets);
    });

    testWidgets('defaults to W4 and renders its assessment', (tester) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.text('Pushpadanta'), findsWidgets);
      expect(find.text('Favorable'), findsWidgets);

      expect(
        find.text(
          'A traditionally favorable west entrance associated with prosperity, stability and positive growth.',
        ),
        findsOneWidget,
      );

      expect(find.text('W4'), findsWidgets);
    });

    testWidgets('switching to W5 updates the calculated segment and assessment', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());

      final w5 = find.byKey(const Key('vastu-pada-selector-W5'));
      await tester.ensureVisible(w5);
      await tester.tap(w5);
      await tester.pumpAndSettle();

      expect(find.text('Varuna'), findsWidgets);
      expect(find.text('Pushpadanta'), findsNothing);

      expect(
        find.text(
          'A traditionally favorable west entrance associated with stability, gains and broader opportunities.',
        ),
        findsOneWidget,
      );

      expect(find.text('W5'), findsWidgets);
    });

    testWidgets('changing position from W4 into W6 removes the W4 assessment', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.text('Pushpadanta'), findsWidgets);
      expect(find.text('W4'), findsWidgets);

      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);

      await tester.ensureVisible(slider);

      final sliderBox = tester.renderObject<RenderBox>(slider);
      final sliderCenter = sliderBox.localToGlobal(
        sliderBox.size.center(Offset.zero),
      );

      // 70% moves clearly into the unsupported W6 range.
      await tester.tapAt(
        Offset(
          sliderBox.localToGlobal(Offset.zero).dx + sliderBox.size.width * 0.70,
          sliderCenter.dy,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('W6'), findsWidgets);
      expect(find.text('Pushpadanta'), findsNothing);
      expect(find.text('Varuna'), findsNothing);
      expect(
        find.text('Assessment not available yet for this entrance pada.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'changing direction from West to East removes the west assessment',
      (tester) async {
        await tester.pumpWidget(buildTestApp());

        expect(find.text('Pushpadanta'), findsWidgets);

        final dropdown = find.byType(
          DropdownButtonFormField<VastuEntryDirection>,
        );
        expect(dropdown, findsOneWidget);

        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        expect(find.text('East'), findsWidgets);

        await tester.tap(find.text('East').last);
        await tester.pumpAndSettle();

        expect(find.text('Pushpadanta'), findsNothing);
        expect(find.text('Varuna'), findsNothing);

        expect(
          find.text('Assessment not available yet for this entrance pada.'),
          findsOneWidget,
        );

        expect(find.text('E4'), findsWidgets);
      },
    );

    testWidgets('tapping W1 and W8 updates the calculated pada', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());

      final w1 = find.byKey(const Key('vastu-pada-selector-W1'));
      await tester.ensureVisible(w1);
      await tester.tap(w1);
      await tester.pumpAndSettle();

      expect(find.text('W1'), findsWidgets);
      expect(
        find.text('Assessment not available yet for this entrance pada.'),
        findsOneWidget,
      );
      expect(find.text('Pushpadanta'), findsNothing);
      expect(find.text('Varuna'), findsNothing);

      final w8 = find.byKey(const Key('vastu-pada-selector-W8'));
      await tester.ensureVisible(w8);
      await tester.tap(w8);
      await tester.pumpAndSettle();

      expect(find.text('W8'), findsWidgets);
      expect(
        find.text('Assessment not available yet for this entrance pada.'),
        findsOneWidget,
      );
    });

    testWidgets('each cardinal direction exposes all eight padas', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());

      final dropdown = find.byType(
        DropdownButtonFormField<VastuEntryDirection>,
      );
      expect(dropdown, findsOneWidget);

      for (final direction in const [
        ('North', 'N'),
        ('East', 'E'),
        ('South', 'S'),
        ('West', 'W'),
      ]) {
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        await tester.tap(find.text(direction.$1).last);
        await tester.pumpAndSettle();

        for (var pada = 1; pada <= 8; pada++) {
          expect(find.text('${direction.$2}$pada'), findsWidgets);
        }
      }
    });

    testWidgets(
      'tapping an unsupported pada removes any supported assessment',
      (tester) async {
        await tester.pumpWidget(buildTestApp());

        expect(find.text('Pushpadanta'), findsWidgets);

        final w6 = find.byKey(const Key('vastu-pada-selector-W6'));
        await tester.ensureVisible(w6);
        await tester.tap(w6);
        await tester.pumpAndSettle();

        expect(find.text('W6'), findsWidgets);
        expect(find.text('Pushpadanta'), findsNothing);
        expect(find.text('Varuna'), findsNothing);
        expect(
          find.text('Assessment not available yet for this entrance pada.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('changing direction keeps the selected pada number', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());

      final w5 = find.byKey(const Key('vastu-pada-selector-W5'));
      await tester.ensureVisible(w5);
      await tester.tap(w5);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vastu-calculated-pada')), findsOneWidget);
      expect(find.text('Varuna'), findsWidgets);

      final dropdown = find.byType(
        DropdownButtonFormField<VastuEntryDirection>,
      );
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('North').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vastu-calculated-pada')), findsOneWidget);
      expect(find.text('N5'), findsWidgets);
      expect(find.text('Varuna'), findsNothing);
      expect(find.text('Pushpadanta'), findsNothing);
      expect(
        find.text('Assessment not available yet for this entrance pada.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping map W5 updates page calculation and assessment', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vastu-calculated-pada')), findsOneWidget);
      expect(find.text('Pushpadanta'), findsWidgets);

      final mapW5 = find.byKey(const Key('vastu-map-segment-W5'));

      await tester.ensureVisible(mapW5);
      await tester.tap(mapW5);
      await tester.pumpAndSettle();

      final calculatedPada = tester.widget<Text>(
        find.byKey(const Key('vastu-calculated-pada')),
      );

      expect(calculatedPada.data, 'W5');
      expect(find.text('Varuna'), findsWidgets);
      expect(find.text('Pushpadanta'), findsNothing);
      expect(
        find.text(
          'A traditionally favorable west entrance associated with stability, gains and broader opportunities.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders entrance detail labels', (tester) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.text('Entrance pada'), findsOneWidget);
      expect(find.text('Assessment'), findsOneWidget);
      expect(find.text('Traditional assessment'), findsOneWidget);
    });
  });

  testWidgets('N1 displays Roga as the traditional deity', (tester) async {
    await tester.pumpWidget(buildTestApp());

    final dropdown = find.byKey(const Key('vastu-entry-direction'));
    expect(dropdown, findsOneWidget);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('North').last);
    await tester.pumpAndSettle();

    final n1 = find.byKey(const Key('vastu-pada-selector-N1'));
    expect(n1, findsOneWidget);

    await tester.tap(n1);
    await tester.pumpAndSettle();

    expect(find.text('N1'), findsWidgets);
    expect(find.text('Roga'), findsOneWidget);
    expect(
      find.text('Assessment not available yet for this entrance pada.'),
      findsOneWidget,
    );
  });

  testWidgets('E4 displays Indra as the traditional deity', (tester) async {
    await tester.pumpWidget(buildTestApp());

    final dropdown = find.byKey(const Key('vastu-entry-direction'));
    expect(dropdown, findsOneWidget);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('East').last);
    await tester.pumpAndSettle();

    final e4 = find.byKey(const Key('vastu-pada-selector-E4'));
    expect(e4, findsOneWidget);

    await tester.tap(e4);
    await tester.pumpAndSettle();

    expect(find.text('E4'), findsWidgets);
    expect(find.text('Indra'), findsOneWidget);
    expect(
      find.text('Assessment not available yet for this entrance pada.'),
      findsOneWidget,
    );
  });

  testWidgets('S5 displays Yama as the traditional deity', (tester) async {
    await tester.pumpWidget(buildTestApp());

    final dropdown = find.byKey(const Key('vastu-entry-direction'));
    expect(dropdown, findsOneWidget);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('South').last);
    await tester.pumpAndSettle();

    final s5 = find.byKey(const Key('vastu-pada-selector-S5'));
    expect(s5, findsOneWidget);

    await tester.tap(s5);
    await tester.pumpAndSettle();

    expect(find.text('S5'), findsWidgets);
    expect(find.text('Yama'), findsOneWidget);
    expect(
      find.text('Assessment not available yet for this entrance pada.'),
      findsOneWidget,
    );
  });

  testWidgets('W6 displays Asura as the traditional deity', (tester) async {
    await tester.pumpWidget(buildTestApp());

    final w6 = find.byKey(const Key('vastu-pada-selector-W6'));
    expect(w6, findsOneWidget);

    await tester.tap(w6);
    await tester.pumpAndSettle();

    expect(find.text('W6'), findsWidgets);
    expect(find.text('Asura'), findsOneWidget);
    expect(
      find.text('Assessment not available yet for this entrance pada.'),
      findsOneWidget,
    );
  });
}
