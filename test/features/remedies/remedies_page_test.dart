import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/core/time/app_clock_provider.dart';
import 'package:rv_astro_vastu/features/astrology/presentation/providers/astrology_provider.dart';
import 'package:rv_astro_vastu/features/astrology/presentation/utils/astrology_localization.dart';
import 'package:rv_astro_vastu/features/birth_profile/data/models/birth_profile_model.dart';
import 'package:rv_astro_vastu/features/birth_profile/domain/entities/birth_location.dart';
import 'package:rv_astro_vastu/features/birth_profile/presentation/providers/birth_profile_provider.dart';
import 'package:rv_astro_vastu/features/dosha/presentation/providers/dosha_provider.dart';
import 'package:rv_astro_vastu/features/remedies/presentation/remedies_page.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

import '../membership/premium_test_helper.dart';

import '../dosha/dosha_test_helpers.dart';

class _Profile extends BirthProfileNotifier {
  @override
  BirthProfileModel? build() => BirthProfileModel.create(
    name: 'LV',
    gender: 'Female',
    dateOfBirth: DateTime(1987, 12, 13),
    birthTime: '00:42',
    location: const BirthLocation(
      city: 'New Delhi',
      latitude: 28.6139,
      longitude: 77.209,
      timezone: 'Asia/Kolkata',
    ),
  );
}

class _FixedClock extends AppClockNotifier {
  @override
  DateTime build() => DateTime(2026, 10, 17, 10);
}

void main() {
  testWidgets('shows Lagna-based gemstones and period remedies', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Virgo Lagna with the Moon in Leo (the 13 Dec 1987 Delhi chart).
    final kundali = kundaliFrom(
      ascendant: inSign('Virgo', 2.92),
      longitudes: {
        'Sun': 236.53,
        'Moon': 139.01,
        'Mars': 198.55,
        'Mercury': 230.70,
        'Jupiter': 356.09,
        'Venus': 264.59,
        'Saturn': 239.52,
        'Rahu': 334.50,
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumOverride,
          birthProfileProvider.overrideWith(_Profile.new),
          kundaliProvider.overrideWith((ref) async => kundali),
          doshaReportProvider.overrideWith((ref) async => null),
          appClockProvider.overrideWith(_FixedClock.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: [Locale('en')],
          home: RemediesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Mercury (life), Saturn (lucky, also rules the 6th), Venus (fortune).
    expect(find.text(l10n.remediesGemName('mercury')), findsOneWidget);
    expect(find.text(l10n.remediesGemName('saturn')), findsOneWidget);
    expect(find.text(l10n.remediesGemName('venus')), findsOneWidget);
    expect(
      find.text(l10n.remediesGemCaution(l10n.planetName('Saturn'))),
      findsOneWidget,
    );

    // A current-period card with a mantra.
    expect(find.text(l10n.remediesPeriodsTitle), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);

    expect(find.text(l10n.remediesNoDoshas), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
