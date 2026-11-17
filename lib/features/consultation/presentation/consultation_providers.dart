import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/app_clock_provider.dart';
import '../data/consultation_repository.dart';
import '../domain/consultation.dart';

final consultationRepositoryProvider = Provider<ConsultationRepository>(
  (ref) => const ConsultationRepository(),
);

/// Bookable days and times from now, without slots already held.
final consultationSlotsProvider =
    FutureProvider.autoDispose<List<(DateTime, List<DateTime>)>>((ref) async {
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
      return availableSlots(now: now, taken: taken);
    });

/// The user's own requests, newest slot first.
final myConsultationsProvider =
    FutureProvider.autoDispose<List<ConsultationRequest>>(
      (ref) => ref.watch(consultationRepositoryProvider).mine(),
    );
