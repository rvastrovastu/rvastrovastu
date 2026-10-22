import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/core/location/current_location.dart';
import 'package:rv_astro_vastu/core/location/current_location_provider.dart';
import 'package:rv_astro_vastu/core/location/device_time_zone.dart';
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
  String? zone,
}) async {
  final container = ProviderContainer(
    overrides: [
      currentLocationProvider.overrideWith(() => _Location(live)),
      birthProfileProvider.overrideWith(() => _Profile(profile)),
      deviceTimeZoneProvider.overrideWith((ref) async => zone),
    ],
  );
  addTearDown(container.dispose);
  await container.read(currentLocationProvider.future);
  await container.read(deviceTimeZoneProvider.future);
  return container.read(panchangPlaceProvider).value;
}

void main() {
  test('uses the phone location when there is one', () async {
    final place = await _place(live: _dallas, profile: _delhiProfile());
    expect(place!.location.timezone, 'America/Chicago');
    expect(place.source, PlaceSource.gps);
  });

  test('without GPS, follows the phone time zone, not the birth city', () async {
    final place = await _place(
      profile: _delhiProfile(),
      zone: 'America/Chicago',
    );
    expect(place!.source, PlaceSource.timeZone);
    expect(place.location.timezone, 'America/Chicago');
    expect(place.location.city, 'Chicago');
    expect(place.location.latitude, closeTo(41.85, 0.01));
  });

  test('uses the birth city when it is in the phone time zone', () async {
    // Old zone names count as the same zone.
    final place = await _place(profile: _delhiProfile(), zone: 'Asia/Calcutta');
    expect(place!.source, PlaceSource.profile);
    expect(place.location.city, 'New Delhi');
  });

  test('falls back to the birth-profile city without GPS or zone', () async {
    final place = await _place(profile: _delhiProfile());
    expect(place!.source, PlaceSource.profile);
    expect(place.location.city, 'New Delhi');
    expect(place.location.timezone, 'Asia/Kolkata');
  });

  test('is empty with none of them', () async {
    expect(await _place(), isNull);
    expect(await _place(zone: 'Etc/UTC'), isNull);
  });

  test('zone names map to their principal city', () {
    expect(canonicalZone('US/Central'), 'America/Chicago');
    expect(timeZonePlace('Asia/Kolkata')!.city, 'Kolkata');
    expect(timeZonePlace('America/Argentina/Buenos_Aires')!.city, 'Buenos Aires');
  });
}
