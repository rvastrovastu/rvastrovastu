import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../data/repositories/swiss_ephemeris_transit_repository.dart';
import '../../domain/entities/transit.dart';
import '../../domain/repositories/transit_repository.dart';
import '../../domain/usecases/analyze_gochar.dart';

final transitRepositoryProvider = Provider<TransitRepository>(
  (ref) => SwissEphemerisTransitRepository(),
);

/// Read once per report so the scan isn't repeated every minute.
final gocharNowProvider = Provider<DateTime>((ref) => DateTime.now());

/// Transits for the active profile, or `null` without one.
final gocharReportProvider = FutureProvider<GocharReport?>((ref) async {
  final now = ref.watch(gocharNowProvider);
  final repository = ref.watch(transitRepositoryProvider);
  final kundali = await ref.watch(kundaliProvider.future);
  if (kundali == null) return null;

  // Start far enough back that each planet's current sign has a known
  // entry date (Saturn stays ~2.5 years, Rahu ~1.5).
  final periods = await repository.signPeriods(
    fromUtc: now.toUtc().subtract(const Duration(days: 365 * 4)),
    toUtc: now.toUtc().add(const Duration(days: 365 * 3)),
  );

  return const AnalyzeGochar()(
    moonSign: kundali.moonSign,
    lagnaSign: kundali.ascendant,
    periods: periods,
    now: now,
  );
});
