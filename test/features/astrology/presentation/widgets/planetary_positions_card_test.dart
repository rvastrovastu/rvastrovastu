import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/astrology/domain/entities/planet_position.dart';
import 'package:rv_astro_vastu/features/astrology/presentation/widgets/planetary_positions_card.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

Widget buildTestApp(List<PlanetPosition> planets) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: SingleChildScrollView(
        child: PlanetaryPositionsCard(planets: planets),
      ),
    ),
  );
}

void main() {
  group('PlanetaryPositionsCard', () {
    testWidgets('displays Nakshatra and Pada when available', (tester) async {
      await tester.pumpWidget(
        buildTestApp([
          const PlanetPosition(
            planet: 'Moon',
            sign: 'Scorpio',
            house: 2,
            longitude: 233.06,
            degree: 23.06,
            nakshatra: 'Hasta',
            nakshatraPada: 2,
          ),
        ]),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hasta • Pada 2'), findsOneWidget);
      expect(find.textContaining('Scorpio'), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets);
    });

    testWidgets('renders correctly when Nakshatra data is unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp([
          const PlanetPosition(
            planet: 'Sun',
            sign: 'Aries',
            house: 1,
            longitude: 10.0,
            degree: 10.0,
          ),
        ]),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Aries'), findsOneWidget);
      expect(find.textContaining('Hasta'), findsNothing);
    });
  });
}
