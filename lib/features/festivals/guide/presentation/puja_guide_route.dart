import '../../domain/entities/calendar_observance.dart';

/// Location of the puja guide for [id], with the date it falls on.
String pujaGuidePath(ObservanceId id, [DateTime? date]) {
  if (date == null) return '/puja-guide/${id.name}';
  String two(int n) => n.toString().padLeft(2, '0');
  return '/puja-guide/${id.name}'
      '?date=${date.year}-${two(date.month)}-${two(date.day)}';
}
