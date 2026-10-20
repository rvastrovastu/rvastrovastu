class DashaBirthData {
  final DateTime birthDate;
  final double moonLongitude;

  const DashaBirthData({required this.birthDate, required this.moonLongitude});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DashaBirthData &&
        other.birthDate == birthDate &&
        other.moonLongitude == moonLongitude;
  }

  @override
  int get hashCode => Object.hash(birthDate, moonLongitude);
}
