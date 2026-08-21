class BirthLocation {
  final String city;
  final String? state;
  final String? country;
  final double latitude;
  final double longitude;
  final String timezone;

  const BirthLocation({
    required this.city,
    this.state,
    this.country,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  String get displayName {
    final parts = <String>[
      city,
      if (state != null && state!.isNotEmpty) state!,
      if (country != null && country!.isNotEmpty) country!,
    ];

    return parts.join(', ');
  }
}
