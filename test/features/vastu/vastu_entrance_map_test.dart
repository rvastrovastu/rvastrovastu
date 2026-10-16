import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/l10n/app_localizations.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_entry_segment.dart';
import 'package:rv_astro_vastu/features/vastu/presentation/widgets/vastu_entrance_map.dart';

void main() {
  Widget buildTestApp({
    VastuEntrySegment selectedSegment = VastuEntrySegment.w4,
    ValueChanged<VastuEntrySegment>? onSegmentSelected,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: VastuEntranceMap(
          selectedSegment: selectedSegment,
          onSegmentSelected: onSegmentSelected ?? (_) {},
        ),
      ),
    );
  }

  group('VastuEntranceMap', () {
    testWidgets('renders all 32 cardinal wall segments', (tester) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.byType(VastuEntranceMap), findsOneWidget);

      for (final segment in VastuEntrySegment.values) {
        expect(
          find.byKey(Key('vastu-map-segment-${segment.code}')),
          findsOneWidget,
          reason: 'Missing map segment ${segment.code}',
        );
      }
    });

    testWidgets('selects W4 by default', (tester) async {
      await tester.pumpWidget(buildTestApp());

      final selectedSegment = find.byKey(const Key('vastu-map-segment-W4'));

      expect(selectedSegment, findsOneWidget);

      final widget = tester.widget<Positioned>(selectedSegment);

      expect(widget.key, const Key('vastu-map-segment-W4'));
    });

    testWidgets('tapping W5 reports W5', (tester) async {
      VastuEntrySegment? selected;

      await tester.pumpWidget(
        buildTestApp(
          onSegmentSelected: (segment) {
            selected = segment;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('vastu-map-segment-W5')));
      await tester.pump();

      expect(selected, VastuEntrySegment.w5);
    });

    testWidgets('tapping representative segments reports correct values', (
      tester,
    ) async {
      final selectedSegments = <VastuEntrySegment>[];

      await tester.pumpWidget(
        buildTestApp(onSegmentSelected: selectedSegments.add),
      );

      const segments = <VastuEntrySegment>[
        VastuEntrySegment.n1,
        VastuEntrySegment.n8,
        VastuEntrySegment.e1,
        VastuEntrySegment.e8,
        VastuEntrySegment.s1,
        VastuEntrySegment.s8,
        VastuEntrySegment.w1,
        VastuEntrySegment.w8,
      ];

      for (final segment in segments) {
        await tester.tap(find.byKey(Key('vastu-map-segment-${segment.code}')));
        await tester.pump();
      }

      expect(selectedSegments, segments);
    });

    testWidgets('selected segment has selected styling', (tester) async {
      await tester.pumpWidget(
        buildTestApp(selectedSegment: VastuEntrySegment.w5),
      );

      final selected = find.byKey(const Key('vastu-map-segment-W5'));

      final selectedDecoration = tester.widget<DecoratedBox>(
        find.descendant(of: selected, matching: find.byType(DecoratedBox)),
      );

      final decoration = selectedDecoration.decoration as BoxDecoration;
      final theme = Theme.of(tester.element(selected));

      expect(decoration.color, theme.colorScheme.primaryContainer);
      expect(decoration.border?.top.color, theme.colorScheme.primary);
      expect(decoration.border?.top.width, 2);
      expect(decoration.borderRadius, BorderRadius.circular(10));
    });

    testWidgets('unselected segment has neutral styling', (tester) async {
      await tester.pumpWidget(
        buildTestApp(selectedSegment: VastuEntrySegment.w5),
      );

      final unselected = find.byKey(const Key('vastu-map-segment-W4'));

      final unselectedDecoration = tester.widget<DecoratedBox>(
        find.descendant(of: unselected, matching: find.byType(DecoratedBox)),
      );

      final decoration = unselectedDecoration.decoration as BoxDecoration;
      final theme = Theme.of(tester.element(unselected));

      expect(decoration.color, Colors.transparent);
      expect(decoration.border?.top.color, theme.colorScheme.outlineVariant);
      expect(decoration.border?.top.width, 1);
      expect(decoration.borderRadius, BorderRadius.circular(10));
    });

    testWidgets('only one map segment has the selected state', (tester) async {
      await tester.pumpWidget(
        buildTestApp(selectedSegment: VastuEntrySegment.w5),
      );

      for (final segment in VastuEntrySegment.values) {
        expect(
          find.byKey(Key('vastu-map-segment-${segment.code}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('localizes the house label', (tester) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.text('HOUSE'), findsOneWidget);
      expect(find.text('House'), findsNothing);
    });

    testWidgets('provides localized semantic labels for map segments', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.bySemanticsLabel('West W4'), findsOneWidget);

      expect(find.bySemanticsLabel('North N1'), findsOneWidget);

      expect(find.bySemanticsLabel('East E8'), findsOneWidget);

      expect(find.bySemanticsLabel('South S8'), findsOneWidget);
    });

    testWidgets('marks selected map segment as selected in semantics', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(
        buildTestApp(selectedSegment: VastuEntrySegment.w5),
      );

      final selected = find.byKey(const Key('vastu-map-semantics-W5'));

      expect(selected, findsOneWidget);

      final semantics = tester.getSemantics(selected);

      expect(semantics.label, 'West W5');
      expect(
        semantics.flagsCollection.isSelected.toString(),
        'Tristate.isTrue',
      );
      expect(semantics.flagsCollection.isButton, isTrue);

      semanticsHandle.dispose();
    });
  });
}
