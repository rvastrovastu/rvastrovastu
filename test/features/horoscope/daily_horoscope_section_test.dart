import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rv_astro_vastu/features/horoscope/domain/entities/daily_horoscope.dart';
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

  testWidgets('shows horoscope date and planetary period', (tester) async {
    final horoscope = DailyHoroscope(
      date: DateTime(2026, 10, 9),
      career: 'Career guidance',
      finance: 'Finance guidance',
      relationships: 'Relationship guidance',
      careerKey: 'mercury',
      financeKey: 'jupiter',
      relationshipsKey: 'venus',
      mahadasha: 'Mercury',
      antardasha: 'Venus',
      nakshatra: 'Anuradha',
    );

    await tester.pumpWidget(buildTestApp(horoscopeAsync: AsyncData(horoscope)));

    expect(find.text('October 9, 2026'), findsOneWidget);
    expect(find.text('Mercury · Venus'), findsOneWidget);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.homeCareer), findsOneWidget);
    expect(find.text(l10n.homeFinance), findsOneWidget);
    expect(find.text(l10n.homeRelationships), findsOneWidget);
  });

  testWidgets('shows fallback cards when horoscope data is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(horoscopeAsync: const AsyncData(null)),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.homeCareer), findsOneWidget);
    expect(find.text(l10n.homeFinance), findsOneWidget);
    expect(find.text(l10n.homeRelationships), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
