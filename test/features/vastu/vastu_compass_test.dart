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

  testWidgets('explains when there is no compass sensor', (tester) async {
    final l10n = await pump(tester, null);

    expect(find.text(l10n.vastuCompassNoSensor), findsOneWidget);
    expect(find.text(l10n.vastuAllZones), findsOneWidget);
  });
}
