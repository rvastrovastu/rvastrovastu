import '../../domain/entities/birth_location.dart';

class BirthProfileModel {
  /// Stable identifier for this saved birth profile.
  final String id;

  final String name;
  final String gender;

  /// Optional relationship to the user.
  /// Examples: Self, Spouse, Child, Parent, Other.
  final String relationship;

  final DateTime dateOfBirth;

  /// Stable 24-hour `HH:mm`, independent of app language/locale.
  final String birthTime;

  /// This is the person's BIRTH location.
  ///
  /// It must not be replaced by the user's current/device location.
  final BirthLocation location;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BirthProfileModel({
    required this.id,
    required this.name,
    required this.gender,
    required this.relationship,
    required this.dateOfBirth,
    required this.birthTime,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BirthProfileModel.create({
    required String name,
    required String gender,
    String relationship = 'Self',
    required DateTime dateOfBirth,
    required String birthTime,
    required BirthLocation location,
  }) {
    final now = DateTime.now();

    return BirthProfileModel(
      id: _generateId(),
      name: name,
      gender: gender,
      relationship: relationship,
      dateOfBirth: dateOfBirth,
      birthTime: birthTime,
      location: location,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory BirthProfileModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    final dateOfBirth = DateTime.parse(json['date_of_birth'] as String);

    final createdAt = _parseDate(json['created_at'], fallback: now);

    final updatedAt = _parseDate(json['updated_at'], fallback: createdAt);

    final location = BirthLocation(
      city: json['birth_city'] as String? ?? '',
      state: json['birth_state'] as String?,
      country: json['birth_country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      timezone: json['timezone'] as String? ?? 'UTC',
    );

    return BirthProfileModel(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? json['id'] as String
          : _generateId(),
      name: json['name'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      relationship: json['relationship'] as String? ?? 'Self',
      dateOfBirth: dateOfBirth,
      birthTime: json['birth_time'] as String? ?? '',
      location: location,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'relationship': relationship,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'birth_time': birthTime,
      'birth_city': location.city,
      'birth_state': location.state,
      'birth_country': location.country,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'timezone': location.timezone,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BirthProfileModel copyWith({
    String? id,
    String? name,
    String? gender,
    String? relationship,
    DateTime? dateOfBirth,
    String? birthTime,
    BirthLocation? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BirthProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      relationship: relationship ?? this.relationship,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      birthTime: birthTime ?? this.birthTime,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _generateId() {
    return '${DateTime.now().microsecondsSinceEpoch}';
  }

  static DateTime _parseDate(dynamic value, {required DateTime fallback}) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? fallback;
    }

    return fallback;
  }
}
