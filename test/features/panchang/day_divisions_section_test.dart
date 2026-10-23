import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/panchang/data/repositories/swiss_ephemeris_sun_times_repository.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/daily_panchang_input.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/day_divisions.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/providers/day_divisions_provider.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/widgets/day_divisions_section.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Sunrise 06:00 and sunset 18:00 UTC every day.
class _EvenSun extends SwissEphemerisSunTimesRepository {
  @override
  Future<SunTimes?> sunTimes({
    required DateTime date,
    required double latitude,
    required double longitude,
    required String timezone,
  }) async => SunTimes(
    sunrise: DateTime.utc(date.year, date.month, date.day, 6),
    sunset: DateTime.utc(date.year, date.month, date.day, 18),
    nextSunrise: DateTime.utc(date.year, date.month, date.day + 1, 6),
  );
}

Future<AppLocalizations> _pump(
  WidgetTester tester,
  DateTime now, {
  bool withChoghadiya = true,
  bool choghadiyaOnly = false,
}) async {
  tester.view.physicalSize = const Size(430, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sunTimesRepositoryProvider.overrideWithValue(_EvenSun())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: SingleChildScrollView(
            child: DayDivisionsSection(
              // Sunday 18 October 2026.
              today: DailyPanchangInput(
                date: DateTime(2026, 10, 18),
                latitude: 0,
                longitude: 0,
                timezone: 'Etc/UTC',
              ),
              now: now,
              withChoghadiya: withChoghadiya,
              choghadiyaOnly: choghadiyaOnly,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('daytime shows the running Choghadiya and switches to night', (
    tester,
  ) async {
    final l10n = await _pump(tester, DateTime.utc(2026, 10, 18, 10));

    expect(find.text(l10n.yamagandaTitle), findsOneWidget);
    expect(find.text(l10n.gulikaTitle), findsOneWidget);
    // Sunday: Udveg opens and closes the day.
    expect(find.text(l10n.choghadiyaName('udveg')), findsNWidgets(2));
    // 09:00–10:30 Labh and the 10:00 Saturn hora are both running.
    expect(find.text(l10n.dayDivisionNow), findsNWidgets(2));
    expect(find.text(l10n.dayDivisionsBeforeSunrise), findsNothing);

    await tester.tap(find.text(l10n.dayDivisionNight));
    await tester.pumpAndSettle();

    // Sunday night: Shubh … Udveg … Shubh.
    expect(find.text(l10n.choghadiyaName('udveg')), findsOneWidget);
    expect(find.text(l10n.choghadiyaName('shubh')), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('before sunrise the previous night is shown', (tester) async {
    final l10n = await _pump(tester, DateTime.utc(2026, 10, 18, 3));

    expect(find.text(l10n.dayDivisionsBeforeSunrise), findsOneWidget);
    // Saturday night: Labh, Udveg, Shubh, Amrit, Chal, Rog, Kaal, Labh.
    // 03:00 falls in the 7th part (Kaal), alongside a running hora.
    expect(find.text(l10n.choghadiyaName('labh')), findsNWidgets(2));
    expect(find.text(l10n.dayDivisionNow), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Daily Timing leaves Choghadiya to the Muhurat planner', (
    tester,
  ) async {
    final l10n = await _pump(
      tester,
      DateTime.utc(2026, 10, 18, 10),
      withChoghadiya: false,
    );

    expect(find.text(l10n.yamagandaTitle), findsOneWidget);
    expect(find.text(l10n.horaTitle), findsOneWidget);
    expect(find.text(l10n.choghadiyaTitle), findsNothing);
    expect(find.text(l10n.choghadiyaName('labh')), findsNothing);
  });

  testWidgets('the Muhurat planner shows only Choghadiya', (tester) async {
    final l10n = await _pump(
      tester,
      DateTime.utc(2026, 10, 18, 10),
      choghadiyaOnly: true,
    );

    expect(find.text(l10n.choghadiyaTitle), findsOneWidget);
    expect(find.text(l10n.choghadiyaName('labh')), findsOneWidget);
    expect(find.text(l10n.yamagandaTitle), findsNothing);
    expect(find.text(l10n.horaTitle), findsNothing);
    // Only the running Choghadiya is marked now; no hora is shown.
    expect(find.text(l10n.dayDivisionNow), findsOneWidget);
  });
}
