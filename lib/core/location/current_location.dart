class CurrentLocation {
  final double latitude;
  final double longitude;
  final String timezone;
  final String? city;
  final String? state;
  final String? country;

  const CurrentLocation({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    this.city,
    this.state,
    this.country,
  });

  String get displayName {
    final parts = <String>[
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
      if (country != null && country!.trim().isNotEmpty) country!.trim(),
    ];

    return parts.isEmpty ? 'Current Location' : parts.join(', ');
  }
}
