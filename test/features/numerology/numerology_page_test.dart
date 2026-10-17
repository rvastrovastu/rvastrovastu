import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/birth_profile/data/models/birth_profile_model.dart';
import 'package:rv_astro_vastu/features/birth_profile/domain/entities/birth_location.dart';
import 'package:rv_astro_vastu/features/birth_profile/presentation/providers/birth_profile_provider.dart';
import 'package:rv_astro_vastu/features/numerology/presentation/numerology_page.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

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

void main() {
  testWidgets('shows Mulank, Bhagyank and a live name number', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [birthProfileProvider.overrideWith(_Profile.new)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: [Locale('en')],
          home: NumerologyPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.numerologyMulank), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // Mulank
    expect(find.text('5'), findsOneWidget); // Bhagyank
    expect(find.text(l10n.numerologyCompound(9)), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ritesh');
    await tester.pump();
    expect(find.text(l10n.numerologyCompound(20)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
