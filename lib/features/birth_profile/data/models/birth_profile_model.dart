import '../../domain/entities/birth_location.dart';

class BirthProfileModel {
  final String name;
  final String gender;
  final DateTime dateOfBirth;

  /// Stored as stable 24-hour `HH:mm`, independent of app language/locale.
  final String birthTime;

  final BirthLocation location;

  const BirthProfileModel({
    required this.name,
    required this.gender,
    required this.dateOfBirth,
    required this.birthTime,
    required this.location,
  });

  factory BirthProfileModel.fromJson(Map<String, dynamic> json) {
    final dateOfBirth = DateTime.parse(json['date_of_birth'] as String);

    final location = BirthLocation(
      city: json['birth_city'] as String? ?? '',
      state: json['birth_state'] as String?,
      country: json['birth_country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      timezone: json['timezone'] as String? ?? 'UTC',
    );

    return BirthProfileModel(
      name: json['name'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      dateOfBirth: dateOfBirth,
      birthTime: json['birth_time'] as String? ?? '',
      location: location,
    );
  }

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
