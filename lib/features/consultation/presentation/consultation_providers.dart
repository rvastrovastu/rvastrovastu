import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/app_clock_provider.dart';
import '../data/consultation_repository.dart';
import '../domain/consultation.dart';

final consultationRepositoryProvider = Provider<ConsultationRepository>(
  (ref) => const ConsultationRepository(),
);

/// Loads the server's consultation prices once per visit and applies them;
/// true when the server's table is in use.
final consultationPricesProvider = FutureProvider.autoDispose<bool>((ref) async {
  final table = await ref.watch(consultationRepositoryProvider).prices();
  if (table == null) return false;
  ConsultationConfig.usePrices(table);
  return true;
});

/// What's already booked, read once per visit. Call [slotsFor] with the
/// session length to get the start times that still fit.
class ConsultationAvailability {
  final DateTime now;
  final Set<DateTime> taken;

  const ConsultationAvailability({required this.now, required this.taken});

  List<(DateTime, List<DateTime>)> slotsFor(int minutes) =>
      availableSlots(now: now, taken: taken, minutes: minutes);
}

/// Bookable days and times from now, without slots already held.
final consultationSlotsProvider =
    FutureProvider.autoDispose<ConsultationAvailability>((ref) async {
      // Read once per visit, not every minute.
      final now = ref.read(appClockProvider);
      var taken = const <DateTime>{};
      try {
        taken = await ref
            .watch(consultationRepositoryProvider)
            .takenSlots(
              now,
              now.add(
                const Duration(days: ConsultationConfig.bookingDays + 1),
              ),
            );
      } catch (_) {
        // Offline or not set up yet: show every slot; the server still
        // refuses a double booking.
      }
      return ConsultationAvailability(now: now, taken: taken);
    });

/// The user's own requests, newest slot first.
final myConsultationsProvider =
    FutureProvider.autoDispose<List<ConsultationRequest>>(
      (ref) => ref.watch(consultationRepositoryProvider).mine(),
    );
