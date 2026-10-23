import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rv_astro_vastu/core/location/current_location.dart';
import 'package:rv_astro_vastu/core/time/app_clock_provider.dart';
import 'package:rv_astro_vastu/features/panchang/data/repositories/swiss_ephemeris_sun_times_repository.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/day_divisions.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/providers/day_divisions_provider.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/providers/panchang_location_provider.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/widgets/choghadiya_strip.dart';
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

/// Sunday 18 October 2026, 10:00 UTC: inside the Labh Choghadiya.
class _SundayTen extends AppClockNotifier {
  @override
  DateTime build() => DateTime.utc(2026, 10, 18, 10);
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('shows the running Choghadiya, its end, and what is next', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: ChoghadiyaStrip())),
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
          appClockProvider.overrideWith(_SundayTen.new),
          panchangPlaceProvider.overrideWithValue(
            const AsyncData(
              PanchangPlace(
                CurrentLocation(
                  latitude: 0,
                  longitude: 0,
                  timezone: 'Etc/UTC',
                ),
              ),
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
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(
      find.textContaining(l10n.choghadiyaName('labh')),
      findsOneWidget,
    );
    // Sunday day: Udveg, Chal, Labh, Amrit… Labh runs 09:00–10:30.
    expect(
      find.text(
        '${l10n.yourDayUntil('10:30 AM')}  ·  '
        '${l10n.choghadiyaNext(l10n.choghadiyaName('amrit'), '10:30 AM')}',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(ChoghadiyaStrip));
    await tester.pumpAndSettle();
    expect(find.text('Muhurat destination'), findsOneWidget);
  });
}
