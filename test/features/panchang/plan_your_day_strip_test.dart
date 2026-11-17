import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rv_astro_vastu/core/location/current_location.dart';
import 'package:rv_astro_vastu/core/time/app_clock_provider.dart';
import 'package:rv_astro_vastu/features/panchang/data/repositories/swiss_ephemeris_sun_times_repository.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/daily_panchang.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/day_divisions.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/providers/daily_panchang_provider.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/providers/day_divisions_provider.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/providers/panchang_location_provider.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/widgets/plan_your_day_strip.dart';
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

/// Sunday 18 October 2026, at the hour given (UTC).
DateTime _sunday(int hour) => DateTime.utc(2026, 10, 18, hour);

Future<AppLocalizations> _pump(
  WidgetTester tester,
  DateTime now, {
  Widget? personal,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PlanYourDayStrip(personal: personal),
          ),
        ),
      ),
      GoRoute(
        path: '/muhurat',
        builder: (context, state) =>
            const Scaffold(body: Text('Muhurat destination')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sunTimesRepositoryProvider.overrideWithValue(_EvenSun()),
        appClockProvider.overrideWith(() => _FixedClock(now)),
        panchangPlaceProvider.overrideWithValue(
          const AsyncData(
            PanchangPlace(
              CurrentLocation(latitude: 0, longitude: 0, timezone: 'Etc/UTC'),
            ),
          ),
        ),
        dailyPanchangProvider.overrideWith(
          (ref, input) async => DailyPanchang(
            date: input.date,
            tithi: 'Shukla Saptami',
            nakshatra: 'Uttara Ashadha',
            yoga: 'Dhriti',
            sunrise: '06:00 AM',
            sunset: '06:00 PM',
            moonrise: '12:30 PM',
            rahuKaal: '04:30 PM – 06:00 PM',
            muhurat: '11:36 AM – 12:24 PM',
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

class _FixedClock extends AppClockNotifier {
  final DateTime fixed;

  _FixedClock(this.fixed);

  @override
  DateTime build() => fixed;
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('shows Muhurat, Rahu Kaal, Choghadiya and Hora for now', (
    tester,
  ) async {
    final l10n = await _pump(tester, _sunday(10));

    expect(find.text(l10n.planYourDayWithPanchang), findsOneWidget);
    expect(find.text('11:36 AM – 12:24 PM'), findsOneWidget);
    expect(find.text('04:30 PM – 06:00 PM'), findsOneWidget);
    // Sunday 09:00–10:30 is Labh; Amrit follows.
    expect(
      find.text(
        '${l10n.choghadiyaName('labh')} · ${l10n.choghadiyaQuality('good')}',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '${l10n.yourDayUntil('10:30 AM')}\n'
        '${l10n.choghadiyaNext(l10n.choghadiyaName('amrit'), '10:30 AM')}',
      ),
      findsOneWidget,
    );
    // Sunday's 10:00 hora is Saturn's; Jupiter's follows.
    expect(find.text(l10n.saturn), findsOneWidget);
    expect(
      find.text(
        '${l10n.yourDayUntil('11:00 AM')}\n'
        '${l10n.choghadiyaNext(l10n.jupiter, '11:00 AM')}',
      ),
      findsOneWidget,
    );
    // Neither Abhijit nor Rahu Kaal is running at 10:00.
    expect(find.text(l10n.dayDivisionNow), findsNothing);

    await tester.tap(find.text(l10n.planYourDayWithPanchang));
    await tester.pumpAndSettle();
    expect(find.text('Muhurat destination'), findsOneWidget);
  });

  testWidgets('marks Abhijit Muhurat when it is running', (tester) async {
    final l10n = await _pump(tester, _sunday(12));

    expect(find.text(l10n.dayDivisionNow), findsOneWidget);
  });

  test('Rahu Kaal and Abhijit follow the Panchang rules', () {
    final sunday = DayDivisions.calculate(
      SunTimes(
        sunrise: _sunday(6),
        sunset: _sunday(18),
        nextSunrise: DateTime.utc(2026, 10, 19, 6),
      ),
      DateTime.sunday,
    );
    // Sunday: the 8th of eight daytime parts.
    expect(sunday.rahuKaal.start, DateTime.utc(2026, 10, 18, 16, 30));
    expect(sunday.rahuKaal.end, _sunday(18));
    // The 8th of fifteen 48-minute muhurtas.
    expect(sunday.abhijit.start, DateTime.utc(2026, 10, 18, 11, 36));
    expect(sunday.abhijit.end, DateTime.utc(2026, 10, 18, 12, 24));
  });

  testWidgets('with a personal view, shows For you first and Today on tap', (
    tester,
  ) async {
    final l10n = await _pump(
      tester,
      _sunday(10),
      personal: const Text('Personal hours'),
    );

    expect(find.text(l10n.timingsForYou), findsOneWidget);
    expect(find.text('Personal hours'), findsOneWidget);
    expect(find.text(l10n.horaLabel), findsNothing);

    await tester.tap(find.text(l10n.timingsToday));
    await tester.pumpAndSettle();
    expect(find.text('Personal hours'), findsNothing);
    expect(find.text(l10n.horaLabel), findsOneWidget);
  });

  testWidgets('without a personal view there are no tabs', (tester) async {
    final l10n = await _pump(tester, _sunday(10));
    expect(find.text(l10n.timingsForYou), findsNothing);
  });
}
