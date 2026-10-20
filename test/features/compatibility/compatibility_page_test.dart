import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rv_astro_vastu/features/astrology/data/repositories/astrology_repository.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/kundali.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/planet_position.dart';
import 'package:rv_astro_vastu/features/astrology/domain/models/kundali_input.dart';
import 'package:rv_astro_vastu/features/astrology/presentation/providers/astrology_provider.dart';
import 'package:rv_astro_vastu/features/birth_profile/data/models/birth_profile_model.dart';
import 'package:rv_astro_vastu/features/birth_profile/domain/entities/birth_location.dart';
import 'package:rv_astro_vastu/features/birth_profile/presentation/providers/birth_profile_provider.dart';
import 'package:rv_astro_vastu/features/compatibility/presentation/pages/compatibility_page.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

class _FixedProfilesNotifier extends BirthProfilesNotifier {
  _FixedProfilesNotifier(this.profiles);

  final List<BirthProfileModel> profiles;

  @override
  List<BirthProfileModel> build() => profiles;
}

class _MockAstrologyRepository implements AstrologyRepository {
  int calls = 0;

  @override
  Future<Kundali> calculateKundali(KundaliInput input) async {
    calls++;

    return Kundali(
      ascendant: 'Aries',
      ayanamsa: 23.85,
      ascendantDegree: 12.5,
      moonLongitude: 48.4,
      moonSign: 'Taurus',
      sunSign: 'Capricorn',
      nakshatra: 'Rohini',
      nakshatraPada: 2,
      planets: const [
        PlanetPosition(
          planet: 'Moon',
          sign: 'Taurus',
          house: 2,
          longitude: 48.4,
          degree: 18.4,
        ),
      ],
    );
  }
}

BirthProfileModel _profile({
  required String id,
  required String name,
  String birthTime = '07:30',
}) {
  final now = DateTime.now();

  return BirthProfileModel(
    id: id,
    name: name,
    gender: name == 'Bride' ? 'Female' : 'Male',
    relationship: name,
    dateOfBirth: DateTime(1992, 10, 29),
    birthTime: birthTime,
    location: const BirthLocation(
      city: 'Dallas',
      state: 'Texas',
      country: 'USA',
      latitude: 32.7767,
      longitude: -96.7970,
      timezone: 'America/Chicago',
    ),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late GoRouter router;
  late _MockAstrologyRepository repository;

  Future<void> pumpCompatibilityPage(
    WidgetTester tester, {
    required List<BirthProfileModel> profiles,
  }) async {
    repository = _MockAstrologyRepository();

    router = GoRouter(
      initialLocation: '/compatibility',
      routes: [
        GoRoute(
          path: '/compatibility',
          builder: (context, state) => const CompatibilityPage(),
        ),
        GoRoute(
          path: '/saved-profiles',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Saved profiles destination')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          birthProfilesProvider.overrideWith(
            () => _FixedProfilesNotifier(profiles),
          ),
          astrologyRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  tearDown(() {
    router.dispose();
  });

  testWidgets(
    'shows saved-profile guidance when fewer than two profiles exist',
    (tester) async {
      await pumpCompatibilityPage(tester, profiles: const []);

      expect(find.text('Marriage Compatibility'), findsOneWidget);
      expect(
        find.text(
          'Please save at least two birth profiles before '
          'calculating compatibility.',
        ),
        findsOneWidget,
      );
      expect(find.text('Manage Birth Profiles'), findsOneWidget);
      expect(repository.calls, 0);

      await tester.tap(find.text('Manage Birth Profiles'));
      await tester.pumpAndSettle();

      expect(find.text('Saved profiles destination'), findsOneWidget);
    },
  );

  testWidgets('blocks calculation when a saved birth time is invalid', (
    tester,
  ) async {
    final profiles = [
      _profile(id: 'bride-1', name: 'Bride', birthTime: '7:30 AM'),
      _profile(id: 'groom-1', name: 'Groom'),
    ];

    await pumpCompatibilityPage(tester, profiles: profiles);

    await tester.tap(find.text('Calculate Compatibility'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Bride profile has an invalid birth time.'),
      findsOneWidget,
    );
    expect(repository.calls, 0);
    expect(find.text('Eight Kootas'), findsNothing);
  });

  testWidgets('calculates compatibility and displays eight Kootas', (
    tester,
  ) async {
    final profiles = [
      _profile(id: 'bride-1', name: 'Bride'),
      _profile(id: 'groom-1', name: 'Groom'),
    ];

    await pumpCompatibilityPage(tester, profiles: profiles);

    await tester.tap(find.text('Calculate Compatibility'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Ashtakoota score'), findsOneWidget);
    expect(find.text('Eight Kootas'), findsOneWidget);
    expect(find.textContaining(' / 36'), findsOneWidget);

    for (final name in [
      'Varna',
      'Vashya',
      'Tara',
      'Yoni',
      'Graha Maitri',
      'Gana',
      'Bhakoot',
      'Nadi',
    ]) {
      expect(find.text(name), findsOneWidget, reason: 'Missing Koota: $name');
    }

    await tester.scrollUntilVisible(
      find.textContaining('Traditional astrology interpretation only.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('Traditional astrology interpretation only.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Traditional astrology interpretation only.'),
      findsOneWidget,
    );
  });
}
