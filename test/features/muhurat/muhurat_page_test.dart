import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rv_astro_vastu/core/location/device_time_zone.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'package:rv_astro_vastu/core/location/current_location.dart';
import 'package:rv_astro_vastu/core/location/current_location_provider.dart';
import 'package:rv_astro_vastu/core/time/app_clock_provider.dart';
import 'package:rv_astro_vastu/features/birth_profile/data/models/birth_profile_model.dart';
import 'package:rv_astro_vastu/features/birth_profile/presentation/providers/birth_profile_provider.dart';
import 'package:rv_astro_vastu/features/muhurat/presentation/pages/muhurat_page.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/daily_panchang.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/daily_panchang_input.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/providers/daily_panchang_provider.dart';
import 'package:rv_astro_vastu/features/panchang/data/repositories/swiss_ephemeris_sun_times_repository.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/day_divisions.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/providers/day_divisions_provider.dart';

import '../membership/premium_test_helper.dart';

class _FixedClockNotifier extends AppClockNotifier {
  @override
  DateTime build() => DateTime.utc(2026, 8, 29, 16);
}

class _FixedLocationNotifier extends CurrentLocationNotifier {
  @override
  Future<CurrentLocation?> build() async => const CurrentLocation(
    latitude: 32.95,
    longitude: -96.80,
    timezone: 'America/Chicago',
    city: 'Dallas',
    state: 'Texas',
    country: 'USA',
  );
}

class _UnavailableLocationNotifier extends CurrentLocationNotifier {
  @override
  Future<CurrentLocation?> build() async => null;
}

final _samplePanchang = DailyPanchang(
  date: DateTime(2026, 8, 29),
  tithi: 'Krishna Dwitiya',
  nakshatra: 'Purva Bhadrapada',
  yoga: 'Dhriti',
  sunrise: '06:59 AM',
  sunset: '07:55 PM',
  moonrise: '08:43 PM',
  rahuKaal: '09:00 AM – 10:30 AM',
  muhurat: '11:45 AM – 12:30 PM',
);

class _MonthBoundaryClockNotifier extends AppClockNotifier {
  @override
  DateTime build() => DateTime.utc(2026, 8, 31, 16);
}

class _NoProfileNotifier extends BirthProfileNotifier {
  @override
  BirthProfileModel? build() => null;
}

/// Fixed sunrise and sunset so Choghadiya needs no ephemeris in tests.
class _EvenSun extends SwissEphemerisSunTimesRepository {
  @override
  Future<SunTimes?> sunTimes({
    required DateTime date,
    required double latitude,
    required double longitude,
    required String timezone,
  }) async => SunTimes(
    sunrise: DateTime.utc(date.year, date.month, date.day, 12),
    sunset: DateTime.utc(date.year, date.month, date.day, 23),
    nextSunrise: DateTime.utc(date.year, date.month, date.day + 1, 12),
  );
}

void main() {
  setUpAll(tz.initializeTimeZones);

  testWidgets('shows calculated Muhurat and Panchang details', (tester) async {
    final input = DailyPanchangInput(
      date: DateTime(2026, 8, 29),
      latitude: 32.95,
      longitude: -96.80,
      timezone: 'America/Chicago',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumOverride,
          appClockProvider.overrideWith(_FixedClockNotifier.new),
          sunTimesRepositoryProvider.overrideWithValue(_EvenSun()),
          deviceTimeZoneProvider.overrideWith((ref) async => null),
          currentLocationProvider.overrideWith(_FixedLocationNotifier.new),
          dailyPanchangProvider(
            input,
          ).overrideWith((ref) async => _samplePanchang),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MuhuratPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Muhurat Planner'), findsOneWidget);
    expect(find.text('Plan with Panchang'), findsOneWidget);
    expect(find.text('Dallas, Texas, USA'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Abhijit Muhurat'), 250);
    expect(find.text('Abhijit Muhurat'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('11:45 AM – 12:30 PM'), 250);
    expect(find.text('11:45 AM – 12:30 PM'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Rahu Kaal'), 250);
    expect(find.text('Rahu Kaal'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Krishna Dwitiya'), 250);
    expect(find.text('Krishna Dwitiya'), findsOneWidget);
    expect(find.text('Purva Bhadrapada'), findsOneWidget);
    expect(find.text('Dhriti'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('Traditional guidance only.'),
      250,
    );
    expect(find.textContaining('Traditional guidance only.'), findsOneWidget);
  });

  testWidgets('selecting a purpose keeps Panchang timings general', (
    tester,
  ) async {
    final input = DailyPanchangInput(
      date: DateTime(2026, 8, 29),
      latitude: 32.95,
      longitude: -96.80,
      timezone: 'America/Chicago',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumOverride,
          appClockProvider.overrideWith(_FixedClockNotifier.new),
          sunTimesRepositoryProvider.overrideWithValue(_EvenSun()),
          deviceTimeZoneProvider.overrideWith((ref) async => null),
          currentLocationProvider.overrideWith(_FixedLocationNotifier.new),
          dailyPanchangProvider(
            input,
          ).overrideWith((ref) async => _samplePanchang),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MuhuratPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('11:45 AM – 12:30 PM'), 250);
    expect(find.text('11:45 AM – 12:30 PM'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marriage').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byType(DropdownButtonFormField<String>),
      -250,
    );

    expect(find.text('Marriage'), findsOneWidget);
    expect(find.textContaining('Marriage'), findsNWidgets(3));

    await tester.scrollUntilVisible(find.text('11:45 AM – 12:30 PM'), 250);
    expect(find.text('11:45 AM – 12:30 PM'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('This selection helps organize your plans.'),
      -250,
    );
    expect(
      find.textContaining('This selection helps organize your plans.'),
      findsOneWidget,
    );
  });

  testWidgets('shows guidance when location is unavailable', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumOverride,
          appClockProvider.overrideWith(_FixedClockNotifier.new),
          sunTimesRepositoryProvider.overrideWithValue(_EvenSun()),
          deviceTimeZoneProvider.overrideWith((ref) async => null),
          currentLocationProvider.overrideWith(
            _UnavailableLocationNotifier.new,
          ),
          birthProfileProvider.overrideWith(_NoProfileNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MuhuratPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Muhurat Planner'), findsOneWidget);
    expect(
      find.text(
        'Location is unavailable. Enable location permission '
        'and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('changing the date loads Panchang for the newly selected date', (
    tester,
  ) async {
    final initialInput = DailyPanchangInput(
      date: DateTime(2026, 8, 29),
      latitude: 32.95,
      longitude: -96.80,
      timezone: 'America/Chicago',
    );

    final nextInput = DailyPanchangInput(
      date: DateTime(2026, 8, 30),
      latitude: 32.95,
      longitude: -96.80,
      timezone: 'America/Chicago',
    );

    final nextPanchang = DailyPanchang(
      date: DateTime(2026, 8, 30),
      tithi: 'Date Change Verified',
      nakshatra: 'Uttara Bhadrapada',
      yoga: 'Shoola',
      sunrise: '07:00 AM',
      sunset: '07:54 PM',
      moonrise: '09:15 PM',
      rahuKaal: '05:00 PM – 06:30 PM',
      muhurat: '12:00 PM – 12:45 PM',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumOverride,
          appClockProvider.overrideWith(_FixedClockNotifier.new),
          sunTimesRepositoryProvider.overrideWithValue(_EvenSun()),
          deviceTimeZoneProvider.overrideWith((ref) async => null),
          currentLocationProvider.overrideWith(_FixedLocationNotifier.new),
          dailyPanchangProvider(
            initialInput,
          ).overrideWith((ref) async => _samplePanchang),
          dailyPanchangProvider(
            nextInput,
          ).overrideWith((ref) async => nextPanchang),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MuhuratPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('2026-08-29'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Krishna Dwitiya'), 250);
    expect(find.text('Krishna Dwitiya'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('2026-08-29'), -250);

    await tester.tap(find.text('2026-08-29'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('30').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('2026-08-30'), findsOneWidget);
    expect(find.text('Date Change Verified'), findsOneWidget);
    expect(find.text('Krishna Dwitiya'), findsNothing);
    expect(find.text('12:00 PM – 12:45 PM'), findsOneWidget);
  });

  testWidgets('crossing month boundary loads Panchang for September 1', (
    tester,
  ) async {
    final initialInput = DailyPanchangInput(
      date: DateTime(2026, 8, 31),
      latitude: 32.95,
      longitude: -96.80,
      timezone: 'America/Chicago',
    );

    final nextInput = DailyPanchangInput(
      date: DateTime(2026, 9, 1),
      latitude: 32.95,
      longitude: -96.80,
      timezone: 'America/Chicago',
    );

    final augustPanchang = DailyPanchang(
      date: DateTime(2026, 8, 31),
      tithi: 'August Boundary Baseline',
      nakshatra: 'Uttara Bhadrapada',
      yoga: 'Shoola',
      sunrise: '06:59 AM',
      sunset: '07:55 PM',
      moonrise: '08:43 PM',
      rahuKaal: '09:00 AM – 10:30 AM',
      muhurat: '11:45 AM – 12:30 PM',
    );

    final septemberPanchang = DailyPanchang(
      date: DateTime(2026, 9, 1),
      tithi: 'Month Boundary Verified',
      nakshatra: 'Revati',
      yoga: 'Brahma',
      sunrise: '07:00 AM',
      sunset: '07:54 PM',
      moonrise: '09:15 PM',
      rahuKaal: '05:00 PM – 06:30 PM',
      muhurat: '12:00 PM – 12:45 PM',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumOverride,
          appClockProvider.overrideWith(_MonthBoundaryClockNotifier.new),
          deviceTimeZoneProvider.overrideWith((ref) async => null),
          currentLocationProvider.overrideWith(_FixedLocationNotifier.new),
          dailyPanchangProvider(
            initialInput,
          ).overrideWith((ref) async => augustPanchang),
          dailyPanchangProvider(
            nextInput,
          ).overrideWith((ref) async => septemberPanchang),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MuhuratPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('2026-08-31'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('August Boundary Baseline'), 250);
    expect(find.text('August Boundary Baseline'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('2026-08-31'), -250);

    await tester.tap(find.text('2026-08-31'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('2026-09-01'), findsOneWidget);
    expect(find.text('Month Boundary Verified'), findsOneWidget);
    expect(find.text('August Boundary Baseline'), findsNothing);
    expect(find.text('12:00 PM – 12:45 PM'), findsOneWidget);
  });

  testWidgets(
    'cancelling date selection preserves the current date and Panchang',
    (tester) async {
      final input = DailyPanchangInput(
        date: DateTime(2026, 8, 29),
        latitude: 32.95,
        longitude: -96.80,
        timezone: 'America/Chicago',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            premiumOverride,
            appClockProvider.overrideWith(_FixedClockNotifier.new),
          sunTimesRepositoryProvider.overrideWithValue(_EvenSun()),
            deviceTimeZoneProvider.overrideWith((ref) async => null),
            currentLocationProvider.overrideWith(_FixedLocationNotifier.new),
            dailyPanchangProvider(
              input,
            ).overrideWith((ref) async => _samplePanchang),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MuhuratPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('2026-08-29'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Krishna Dwitiya'), 250);
      expect(find.text('Krishna Dwitiya'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('2026-08-29'), -250);

      await tester.tap(find.text('2026-08-29'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.text('2026-08-29'), findsOneWidget);
      expect(find.text('Krishna Dwitiya'), findsOneWidget);
      expect(find.text('11:45 AM – 12:30 PM'), findsOneWidget);
    },
  );

  testWidgets('selecting a previous-month date loads the matching Panchang', (
    tester,
  ) async {
    final initialInput = DailyPanchangInput(
      date: DateTime(2026, 8, 29),
      latitude: 32.95,
      longitude: -96.80,
      timezone: 'America/Chicago',
    );
    final previousInput = DailyPanchangInput(
      date: DateTime(2026, 7, 31),
      latitude: 32.95,
      longitude: -96.80,
      timezone: 'America/Chicago',
    );
    final julyPanchang = DailyPanchang(
      date: DateTime(2026, 7, 31),
      tithi: 'Previous Month Verified',
      nakshatra: 'Uttara Ashadha',
      yoga: 'Shubha',
      sunrise: '06:30 AM',
      sunset: '08:20 PM',
      moonrise: '09:00 PM',
      rahuKaal: '10:30 AM – 12:00 PM',
      muhurat: '12:15 PM – 01:00 PM',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumOverride,
          appClockProvider.overrideWith(_FixedClockNotifier.new),
          sunTimesRepositoryProvider.overrideWithValue(_EvenSun()),
          deviceTimeZoneProvider.overrideWith((ref) async => null),
          currentLocationProvider.overrideWith(_FixedLocationNotifier.new),
          dailyPanchangProvider(
            initialInput,
          ).overrideWith((ref) async => _samplePanchang),
          dailyPanchangProvider(
            previousInput,
          ).overrideWith((ref) async => julyPanchang),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MuhuratPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('2026-08-29'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Krishna Dwitiya'), 250);
    expect(find.text('Krishna Dwitiya'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('2026-08-29'), -250);

    await tester.tap(find.text('2026-08-29'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('31').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('2026-07-31'), findsOneWidget);
    expect(find.text('Previous Month Verified'), findsOneWidget);
    expect(find.text('Krishna Dwitiya'), findsNothing);
    expect(find.text('12:15 PM – 01:00 PM'), findsOneWidget);
  });
}
