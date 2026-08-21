class BirthLocation {
  final String city;
  final String? state;
  final String country;
  final double latitude;
  final double longitude;
  final String? timezone;

  const BirthLocation({
    required this.city,
    this.state,
    required this.country,
    required this.latitude,
    required this.longitude,
    this.timezone,
  });

  String get displayName {
    final parts = <String>[
      city,
      if (state != null && state!.isNotEmpty) state!,
      country,
    ];

    return parts.join(', ');
  }
}
