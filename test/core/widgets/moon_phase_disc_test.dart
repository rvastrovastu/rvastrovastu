import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/core/widgets/celestial_background.dart';
import 'package:rv_astro_vastu/core/widgets/moon_phase_disc.dart';

void main() {
  test('tithi names map to calculation order', () {
    expect(tithiIndexFromName('Shukla Pratipada'), 0);
    expect(tithiIndexFromName('Purnima'), 14);
    expect(tithiIndexFromName('Krishna Ashtami'), 22);
    expect(tithiIndexFromName('Amavasya'), 29);
    expect(tithiIndexFromName(' Purnima '), 14);
    expect(tithiIndexFromName('—'), isNull);
  });

  test('elongation is the middle of the tithi', () {
    expect(const MoonPhasePainter(0).elongation, 6);
    expect(const MoonPhasePainter(14).elongation, 174);
    expect(const MoonPhasePainter(29).elongation, 354);
  });

  testWidgets('every tithi paints without errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CelestialBackground(
          child: Wrap(
            children: [
              for (var i = 0; i < 30; i++)
                MoonPhaseDisc(tithiIndex: i, size: 40),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(MoonPhaseDisc), findsNWidgets(30));
    expect(tester.takeException(), isNull);
  });
}
