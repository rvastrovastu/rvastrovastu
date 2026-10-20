import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/core/time/app_clock_provider.dart';
import 'package:rv_astro_vastu/features/your_day/data/swiss_ephemeris_moon_repository.dart';
import 'package:rv_astro_vastu/features/your_day/domain/day_strength.dart';
import 'package:rv_astro_vastu/features/your_day/presentation/your_day_card.dart';
import 'package:rv_astro_vastu/features/your_day/presentation/your_day_provider.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

class _FixedMoon extends SwissEphemerisMoonRepository {
  final double longitude;

  _FixedMoon(this.longitude);

  @override
  Future<MoonNow> moonAt(DateTime instant) async => MoonNow(
    longitude: longitude,
    nakshatraEndsUtc: instant.add(const Duration(hours: 5)),
    signEndsUtc: instant.add(const Duration(days: 2)),
  );
}

class _FixedClock extends AppClockNotifier {
  @override
  DateTime build() => DateTime(2026, 10, 20, 9);
}

Future<AppLocalizations> _pump(WidgetTester tester, double transit) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        moonRepositoryProvider.overrideWithValue(_FixedMoon(transit)),
        appClockProvider.overrideWith(_FixedClock.new),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: [Locale('en')],
        home: Scaffold(
          body: SingleChildScrollView(
            // Natal Moon in Leo, Purva Phalguni.
            child: YourDayCard(natalMoonLongitude: 139.01),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  testWidgets('a good day: Sadhaka Tara and Moon 3rd from Leo', (
    tester,
  ) async {
    final l10n = await _pump(tester, 205);

    expect(find.text(l10n.yourDayVerdict('good')), findsOneWidget);
    expect(find.text(l10n.yourDayStrength('good')), findsNWidgets(2));
    expect(
      find.text(l10n.yourDayTaraLine(l10n.yourDayTaraName('sadhaka'), 'Vishakha')),
      findsOneWidget,
    );
    expect(find.text(l10n.yourDayTimings), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chandrashtama makes it a day for caution', (tester) async {
    final l10n = await _pump(tester, 345);

    expect(find.text(l10n.yourDayVerdict('caution')), findsOneWidget);
    expect(find.text(l10n.yourDayChandrashtama), findsOneWidget);
    // Uttara Bhadrapada is also Vadha Tara (7th) from Purva Phalguni.
    expect(find.text(l10n.yourDayStrength('bad')), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
