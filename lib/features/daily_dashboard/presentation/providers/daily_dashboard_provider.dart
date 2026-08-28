import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/daily_dashboard.dart';
import '../../domain/usecases/get_daily_dashboard.dart';

final getDailyDashboardProvider = Provider<GetDailyDashboard>((ref) {
  return const GetDailyDashboard();
});

final dailyDashboardProvider =
    Provider.family<DailyDashboard, DailyDashboardInput>((ref, input) {
      final useCase = ref.watch(getDailyDashboardProvider);

      return useCase.execute(
        date: input.date,
        tithi: input.tithi,
        nakshatra: input.nakshatra,
        mahadasha: input.mahadasha,
        antardasha: input.antardasha,
        rashi: input.rashi,
        yoga: input.yoga,
        sunrise: input.sunrise,
        sunset: input.sunset,
        muhurat: input.muhurat,
        rahuKaal: input.rahuKaal,
      );
    });

class DailyDashboardInput {
  final DateTime date;
  final String rashi;
  final String tithi;
  final String nakshatra;
  final String yoga;
  final String mahadasha;
  final String antardasha;
  final String sunrise;
  final String sunset;
  final String muhurat;
  final String rahuKaal;

  const DailyDashboardInput({
    required this.date,
    this.rashi = '',
    required this.tithi,
    required this.nakshatra,
    this.yoga = '',
    required this.mahadasha,
    required this.antardasha,
    this.sunrise = '',
    this.sunset = '',
    this.muhurat = '',
    this.rahuKaal = '',
  });
}
