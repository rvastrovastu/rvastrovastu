import '../entities/lunar_calendar_data.dart';

abstract class LunarCalendarRepository {
  /// Astronomical data for local dates [fromDate]..[toDate] (inclusive) at
  /// the given location. Implementations include enough lunar data before
  /// and after the range to name the lunar months at its edges.
  Future<LunarCalendarData> calculate({
    required DateTime fromDate,
    required DateTime toDate,
    required double latitude,
    required double longitude,
    required String timezone,
  });
}
