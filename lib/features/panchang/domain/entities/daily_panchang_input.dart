class DailyPanchangInput {
  final DateTime date;
  final double latitude;
  final double longitude;
  final String timezone;

  const DailyPanchangInput({
    required this.date,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DailyPanchangInput &&
        other.date == date &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.timezone == timezone;
  }

  @override
  int get hashCode => Object.hash(date, latitude, longitude, timezone);
}
