import '../../domain/entities/birth_location.dart';

class BirthProfileModel {
  final String name;
  final String gender;
  final DateTime dateOfBirth;
  final String birthTime;
  final BirthLocation location;

  const BirthProfileModel({
    required this.name,
    required this.gender,
    required this.dateOfBirth,
    required this.birthTime,
    required this.location,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gender': gender,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'birth_time': birthTime,
      'birth_city': location.city,
      'birth_state': location.state,
      'birth_country': location.country,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'timezone': location.timezone,
    };
  }
}
