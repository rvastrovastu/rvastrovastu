import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/core/location/current_location.dart';
import 'package:rv_astro_vastu/core/location/current_location_provider.dart';
import 'package:rv_astro_vastu/features/birth_profile/data/models/birth_profile_model.dart';
import 'package:rv_astro_vastu/features/birth_profile/domain/entities/birth_location.dart';
import 'package:rv_astro_vastu/features/birth_profile/presentation/providers/birth_profile_provider.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/providers/panchang_location_provider.dart';

const _dallas = CurrentLocation(
  latitude: 32.78,
  longitude: -96.8,
  timezone: 'America/Chicago',
);

class _Location extends CurrentLocationNotifier {
  final CurrentLocation? value;

  _Location(this.value);

  @override
  Future<CurrentLocation?> build() async => value;
}

class _Profile extends BirthProfileNotifier {
  final BirthProfileModel? value;

  _Profile(this.value);

  @override
  BirthProfileModel? build() => value;
}

BirthProfileModel _delhiProfile() {
  final now = DateTime(2026, 10, 21);
  return BirthProfileModel(
    id: 'p1',
    name: 'Ritu',
    gender: 'Female',
    relationship: 'Self',
    dateOfBirth: DateTime(1990, 1, 1),
    birthTime: '06:00',
    location: const BirthLocation(
      city: 'New Delhi',
      state: 'Delhi',
      country: 'India',
      latitude: 28.6139,
      longitude: 77.209,
      timezone: 'Asia/Kolkata',
    ),
    createdAt: now,
    updatedAt: now,
  );
}

Future<PanchangPlace?> _place({
  CurrentLocation? live,
  BirthProfileModel? profile,
}) async {
  final container = ProviderContainer(
    overrides: [
      currentLocationProvider.overrideWith(() => _Location(live)),
      birthProfileProvider.overrideWith(() => _Profile(profile)),
    ],
  );
  addTearDown(container.dispose);
  await container.read(currentLocationProvider.future);
  return container.read(panchangPlaceProvider).value;
}

void main() {
  test('uses the phone location when there is one', () async {
    final place = await _place(live: _dallas, profile: _delhiProfile());
    expect(place!.location.timezone, 'America/Chicago');
    expect(place.fromProfile, isFalse);
  });

  test('falls back to the birth-profile city without GPS', () async {
    final place = await _place(profile: _delhiProfile());
    expect(place!.fromProfile, isTrue);
    expect(place.location.city, 'New Delhi');
    expect(place.location.timezone, 'Asia/Kolkata');
  });

  test('is empty with neither', () async {
    expect(await _place(), isNull);
  });
}
