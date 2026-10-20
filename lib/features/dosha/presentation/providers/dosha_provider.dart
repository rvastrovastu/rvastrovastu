import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../data/repositories/swiss_ephemeris_saturn_transit_repository.dart';
import '../../domain/entities/kaal_sarp_result.dart';
import '../../domain/entities/manglik_result.dart';
import '../../domain/entities/sade_sati.dart';
import '../../domain/repositories/saturn_transit_repository.dart';
import '../../domain/usecases/calculate_sade_sati.dart';
import '../../domain/usecases/check_kaal_sarp_dosha.dart';
import '../../domain/usecases/check_manglik_dosha.dart';

/// How far ahead to calculate Saturn transits, so the next Sade Sati
/// (Saturn's cycle is ~29.5 years) is always found.
const Duration sadeSatiLookahead = Duration(days: 365 * 32);

final saturnTransitRepositoryProvider = Provider<SaturnTransitRepository>(
  (ref) => SwissEphemerisSaturnTransitRepository(),
);

/// Reference moment for "current" Sade Sati status. Read once per report
/// rather than ticking, so the ephemeris scan is not repeated every minute.
final doshaReferenceDateProvider = Provider<DateTime>((ref) => DateTime.now());

class DoshaReport {
  final Kundali kundali;
  final ManglikResult manglik;
  final KaalSarpResult kaalSarp;
  final SadeSatiReport sadeSati;

  const DoshaReport({
    required this.kundali,
    required this.manglik,
    required this.kaalSarp,
    required this.sadeSati,
  });
}

/// Dosha report for the active birth profile, or `null` without a profile.
final doshaReportProvider = FutureProvider<DoshaReport?>((ref) async {
  // Watch every dependency before the first await.
  final profile = ref.watch(birthProfileProvider);
  final now = ref.watch(doshaReferenceDateProvider);
  final transits = ref.watch(saturnTransitRepositoryProvider);
  final kundaliFuture = ref.watch(kundaliProvider.future);

  if (profile == null) return null;

  final kundali = await kundaliFuture;
  if (kundali == null) return null;

  final birth = profile.dateOfBirth;

  final periods = await transits.saturnSignPeriods(
    fromUtc: DateTime.utc(birth.year, birth.month, birth.day),
    toUtc: now.toUtc().add(sadeSatiLookahead),
  );

  return DoshaReport(
    kundali: kundali,
    manglik: const CheckManglikDosha()(kundali),
    kaalSarp: const CheckKaalSarpDosha()(kundali),
    sadeSati: const CalculateSadeSati()(
      moonSign: kundali.moonSign,
      saturnPeriods: periods,
      referenceDate: now,
    ),
  );
});
