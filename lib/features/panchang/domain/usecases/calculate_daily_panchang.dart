import '../entities/daily_panchang.dart';
import '../repositories/daily_panchang_repository.dart';

class CalculateDailyPanchang {
  final DailyPanchangRepository repository;

  const CalculateDailyPanchang(this.repository);

  Future<DailyPanchang> execute({
    required DateTime date,
    required double latitude,
    required double longitude,
    required String timezone,
  }) {
    return repository.calculate(
      date: date,
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
    );
  }
}
