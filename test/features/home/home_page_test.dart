import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rv_astro_vastu/core/location/current_location.dart';
import 'package:rv_astro_vastu/core/location/current_location_provider.dart';
import 'package:rv_astro_vastu/core/time/app_clock_provider.dart';
import 'package:rv_astro_vastu/features/festivals/presentation/providers/festival_calendar_provider.dart';
import 'package:rv_astro_vastu/features/astrology/presentation/providers/astrology_provider.dart';
import 'package:rv_astro_vastu/features/birth_profile/data/models/birth_profile_model.dart';
import 'package:rv_astro_vastu/features/birth_profile/presentation/providers/birth_profile_provider.dart';
import 'package:rv_astro_vastu/features/home/presentation/pages/home_page.dart';
import 'package:rv_astro_vastu/features/horoscope/presentation/providers/daily_horoscope_provider.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoProfileNotifier extends BirthProfileNotifier {
  @override
  BirthProfileModel? build() => null;
}

class _NoLocationNotifier extends CurrentLocationNotifier {
  @override
  Future<CurrentLocation?> build() async => null;
}

class _FixedClockNotifier extends AppClockNotifier {
  @override
  DateTime build() => DateTime(2026, 10, 8, 10);
}

void main() {
  late GoRouter router;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/birth-profile',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Birth profile destination')),
          ),
        ),
        GoRoute(
          path: '/kundali',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Kundali destination'))),
        ),
        GoRoute(
          path: '/saved-profiles',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Saved profiles destination')),
          ),
        ),
        GoRoute(
          path: '/vastu',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Vastu destination'))),
        ),
      ],
    );
  });

  tearDown(() {
    router.dispose();
  });

  Future<void> pumpHomePage(WidgetTester tester) async {
    // Tall, phone-shaped window: the setup card sits below today's
    // Panchang, outside the default 800×600 test surface.
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          birthProfileProvider.overrideWith(_NoProfileNotifier.new),
          kundaliProvider.overrideWith((ref) async => null),
          dailyHoroscopeProvider.overrideWith((ref) async => null),
          appClockProvider.overrideWith(_FixedClockNotifier.new),
          currentLocationProvider.overrideWith(_NoLocationNotifier.new),
          upcomingFestivalsProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('home shows the setup card when no profile exists', (
    tester,
  ) async {
    await pumpHomePage(tester);

    expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.homeCompleteBirthProfile), findsOneWidget);
    expect(find.text(l10n.homeBirthProfileDescription), findsOneWidget);
    expect(find.text(l10n.homeSetUpProfile), findsOneWidget);
  });

  testWidgets('setup button opens the birth profile route', (tester) async {
    await pumpHomePage(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.ensureVisible(find.text(l10n.homeSetUpProfile));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.homeSetUpProfile));
    await tester.pumpAndSettle();

    expect(find.text('Birth profile destination'), findsOneWidget);
  });
}
