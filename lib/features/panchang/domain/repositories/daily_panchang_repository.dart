import '../entities/daily_panchang.dart';

abstract class DailyPanchangRepository {
  Future<DailyPanchang> calculate({
    required DateTime date,
    required double latitude,
    required double longitude,
    required String timezone,
  });
}
