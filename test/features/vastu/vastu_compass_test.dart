import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/vastu/domain/entities/vastu_zone.dart';
import 'package:rv_astro_vastu/features/vastu/presentation/pages/vastu_compass_page.dart';
import 'package:rv_astro_vastu/features/vastu/presentation/providers/compass_provider.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

void main() {
  group('vastuZoneForHeading', () {
    test('North spans 348.75° to 11.25°', () {
      expect(vastuZoneForHeading(0), VastuZone.n);
      expect(vastuZoneForHeading(11.2), VastuZone.n);
      expect(vastuZoneForHeading(349), VastuZone.n);
      expect(vastuZoneForHeading(348.7), VastuZone.nnw);
      expect(vastuZoneForHeading(11.3), VastuZone.nne);
    });

    test('cardinal and corner zones', () {
      expect(vastuZoneForHeading(45), VastuZone.ne);
      expect(vastuZoneForHeading(90), VastuZone.e);
      expect(vastuZoneForHeading(135), VastuZone.se);
      expect(vastuZoneForHeading(180), VastuZone.s);
      expect(vastuZoneForHeading(225), VastuZone.sw);
      expect(vastuZoneForHeading(270), VastuZone.w);
      expect(vastuZoneForHeading(315), VastuZone.nw);
    });

    test('wraps negative and large headings', () {
      expect(vastuZoneForHeading(-10), VastuZone.n);
      expect(vastuZoneForHeading(405), VastuZone.ne);
    });

    test('zone geometry', () {
      expect(VastuZone.ne.centre, 45);
      expect(VastuZone.n.startBearing, 348.75);
      expect(VastuZone.e.abbreviation, 'E');
    });
  });

  Future<AppLocalizations> pump(WidgetTester tester, double? heading) async {
    // Tall enough to build the zone list below the dial.
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          compassHeadingProvider.overrideWith(
            (ref) => Stream<double?>.value(heading),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: [Locale('en')],
          home: VastuCompassPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.delegate.load(const Locale('en'));
  }

  testWidgets('shows the zone the phone points at', (tester) async {
    final l10n = await pump(tester, 46);

    expect(find.text(l10n.vastuZoneName('ne')), findsWidgets);
    expect(find.text('46° · NE'), findsOneWidget);
    expect(find.text(l10n.vastuCompassHold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a sensor the dial can be turned by hand', (
    tester,
  ) async {
    final l10n = await pump(tester, null);

    expect(find.textContaining(l10n.vastuCompassNoSensor), findsOneWidget);
    expect(find.text(l10n.vastuAllZones), findsOneWidget);
    expect(find.text('0° · N'), findsOneWidget);
    expect(find.text(l10n.vastuCompassHold), findsNothing);

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('manualHeading')),
    );
    slider.onChanged!(90);
    await tester.pumpAndSettle();
    expect(find.text('90° · E'), findsOneWidget);
  });

  group('headingsWithTimeout', () {
    // Real timers with a short timeout: a widget test's fake clock would
    // never let the stream's close finish.
    const timeout = Duration(milliseconds: 40);

    test('gives up waiting when no reading arrives', () async {
      final source = StreamController<double?>();
      final seen = <double?>[];
      final sub = headingsWithTimeout(source.stream, timeout).listen(seen.add);

      expect(seen, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(seen, [null]);

      // A late sensor still gets through.
      source.add(120);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [null, 120]);

      await sub.cancel();
    });

    test('passes readings straight through', () async {
      final source = StreamController<double?>();
      final seen = <double?>[];
      final sub = headingsWithTimeout(source.stream, timeout).listen(seen.add);

      source.add(10);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(seen, [10]);

      await sub.cancel();
    });
  });
}
