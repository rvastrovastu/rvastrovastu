import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_period.dart';
import 'package:rv_astro_vastu/features/horoscope/domain/entities/daily_horoscope.dart';
import 'package:rv_astro_vastu/features/horoscope/domain/usecases/generate_daily_horoscope.dart';
import 'package:rv_astro_vastu/features/horoscope/presentation/widgets/daily_horoscope_section.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

Widget buildTestApp({
  required AsyncValue<DailyHoroscope?> horoscopeAsync,
  VoidCallback? onRetry,
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: DailyHoroscopeSection(
            horoscopeAsync: horoscopeAsync,
            onRetry: onRetry,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows a progress indicator while horoscope is loading', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(horoscopeAsync: const AsyncLoading()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error and retry action when horoscope fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        horoscopeAsync: AsyncError(
          Exception('Test failure'),
          StackTrace.current,
        ),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.error), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets('retry action invokes the supplied callback', (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      buildTestApp(
        horoscopeAsync: AsyncError(
          Exception('Test failure'),
          StackTrace.current,
        ),
        onRetry: () => retryCount++,
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.retry));
    await tester.pump();

    expect(retryCount, 1);
  });

  DailyHoroscope reading(double transitMoon) => GenerateDailyHoroscope().call(
    natalMoonLongitude: 0,
    transitMoonLongitude: transitMoon,
    mahadasha: DashaPeriod(
      planet: DashaPlanet.saturn,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2027, 1, 1),
    ),
    antardasha: DashaPeriod(
      planet: DashaPlanet.mercury,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2027, 1, 1),
    ),
    date: DateTime(2026, 10, 23),
  );

  testWidgets('shows a short reading tied to Tara and Chandra Bala', (
    tester,
  ) async {
    // Bharani in Aries for an Ashwini-born: Sampat Tara, Moon in the 1st.
    await tester.pumpWidget(
      buildTestApp(horoscopeAsync: AsyncData(reading(13.5))),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.horoscopeHeadline('sampat')), findsOneWidget);
    expect(find.text('Sampat Tara'), findsOneWidget);
    expect(find.text(l10n.horoscopeChandraChip('1')), findsOneWidget);
    expect(find.text(l10n.horoscopeCareerLine('h1')), findsOneWidget);
    expect(find.text(l10n.horoscopeMoneyLine('h1')), findsOneWidget);
    expect(find.text(l10n.horoscopeLoveLine('h1')), findsOneWidget);
    expect(find.text(l10n.horoscopeOutlook('good')), findsNWidgets(2));
    expect(find.text(l10n.horoscopeOutlook('steady')), findsOneWidget);
    expect(find.text('Saturn–Mercury dasha'), findsOneWidget);
  });

  testWidgets('Chandrashtama gets its own headline', (tester) async {
    await tester.pumpWidget(
      buildTestApp(horoscopeAsync: AsyncData(reading(215))),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.horoscopeHeadline('chandrashtama')), findsOneWidget);
    expect(find.text(l10n.horoscopeOutlook('careful')), findsNWidgets(3));
  });

  testWidgets('without a profile shows a short prompt, no spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(horoscopeAsync: const AsyncData(null)),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.homeDailyHoroscopeSubtitle), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
