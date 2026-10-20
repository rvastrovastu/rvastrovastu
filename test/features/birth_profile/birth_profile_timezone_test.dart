import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/birth_profile/data/models/birth_profile_model.dart';

Map<String, dynamic> _json({
  Object? timezone,
  double? latitude = 28.6139,
  double? longitude = 77.209,
}) => {
  'id': 'p1',
  'name': 'LV',
  'gender': 'Female',
  'relationship': 'Self',
  'date_of_birth': '1987-12-13T00:00:00.000',
  'birth_time': '00:42',
  'birth_city': 'New Delhi',
  'latitude': ?latitude,
  'longitude': ?longitude,
  'timezone': ?timezone,
};

void main() {
  test('keeps a stored time zone', () {
    final profile = BirthProfileModel.fromJson(
      _json(timezone: 'America/Chicago'),
    );
    expect(profile.location.timezone, 'America/Chicago');
  });

  test('recovers a missing time zone from the birth coordinates', () {
    final profile = BirthProfileModel.fromJson(_json());
    expect(profile.location.timezone, 'Asia/Kolkata');
  });

  test('treats a blank time zone like a missing one', () {
    final profile = BirthProfileModel.fromJson(_json(timezone: '  '));
    expect(profile.location.timezone, 'Asia/Kolkata');
  });

  test('never falls back to UTC without coordinates', () {
    final profile = BirthProfileModel.fromJson(
      _json(latitude: null, longitude: null),
    );
    expect(profile.location.timezone, isEmpty);
    expect(profile.location.timezone, isNot('UTC'));
  });
}
