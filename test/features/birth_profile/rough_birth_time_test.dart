import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/birth_profile/data/models/birth_profile_model.dart';
import 'package:rv_astro_vastu/features/birth_profile/domain/entities/birth_location.dart';
import 'package:rv_astro_vastu/features/birth_profile/domain/rough_birth_time.dart';

void main() {
  test('each part of the day maps to its middle and back', () {
    for (final period in RoughBirthTime.values) {
      expect(RoughBirthTime.fromClock(period.clock), period);
    }
    expect(RoughBirthTime.fromClock('07:41'), RoughBirthTime.noIdea);
  });

  test('an unknown birth time survives saving and loading', () {
    final profile = BirthProfileModel.create(
      name: 'Asha',
      gender: 'female',
      dateOfBirth: DateTime(1960, 5, 1),
      birthTime: RoughBirthTime.morning.clock,
      birthTimeKnown: false,
      location: const BirthLocation(
        city: 'Pune',
        latitude: 18.52,
        longitude: 73.86,
        timezone: 'Asia/Kolkata',
      ),
    );
    final back = BirthProfileModel.fromJson(profile.toJson());
    expect(back.birthTimeKnown, isFalse);
    expect(back.birthTime, '09:00');
  });

  test('profiles saved before this option count as an exact time', () {
    final json = BirthProfileModel.create(
      name: 'Ravi',
      gender: 'male',
      dateOfBirth: DateTime(1985, 3, 10),
      birthTime: '10:15',
      location: const BirthLocation(
        city: 'Delhi',
        latitude: 28.61,
        longitude: 77.21,
        timezone: 'Asia/Kolkata',
      ),
    ).toJson()..remove('birth_time_known');
    expect(BirthProfileModel.fromJson(json).birthTimeKnown, isTrue);
  });
}
