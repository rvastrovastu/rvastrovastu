import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_initialization.dart';
import '../domain/consultation.dart';

/// Thrown when the request can't be sent to the server at all (no
/// Supabase configured, no session), so the app can offer email instead.
class ConsultationUnavailable implements Exception {
  const ConsultationUnavailable();
}

/// Thrown when someone else booked the same slot first.
class ConsultationSlotTaken implements Exception {
  const ConsultationSlotTaken();
}

/// Booking requests in Supabase (`consultation_requests`). Each user sees
/// only their own; booked slots come from `consultation_taken_slots`.
class ConsultationRepository {
  const ConsultationRepository();

  SupabaseClient? get _client {
    if (!AppInitialization.supabaseAvailable) return null;
    final client = AppInitialization.supabase;
    return client.auth.currentUser == null ? null : client;
  }

  bool get isAvailable => _client != null;

  Future<ConsultationRequest> submit(ConsultationRequest request) async {
    final client = _client;
    if (client == null) throw const ConsultationUnavailable();
    try {
      final row = await client
          .from('consultation_requests')
          .insert(request.toInsert())
          .select()
          .single();
      return ConsultationRequest.fromRow(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw const ConsultationSlotTaken();
      rethrow;
    }
  }

  Future<List<ConsultationRequest>> mine() async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('consultation_requests')
        .select()
        .order('slot_start', ascending: false)
        .limit(50);
    return [for (final row in rows) ConsultationRequest.fromRow(row)];
  }

  /// Start times already held by someone (requested or confirmed).
  Future<Set<DateTime>> takenSlots(DateTime from, DateTime to) async {
    final client = _client;
    if (client == null) return const {};
    final rows = await client.rpc(
      'consultation_taken_slots',
      params: {
        'from_time': from.toUtc().toIso8601String(),
        'to_time': to.toUtc().toIso8601String(),
      },
    );
    return {
      for (final row in rows as List)
        DateTime.parse(
          (row is Map ? row['slot_start'] : row) as String,
        ).toUtc(),
    };
  }

  Future<void> cancel(String id) async {
    final client = _client;
    if (client == null) throw const ConsultationUnavailable();
    await client
        .from('consultation_requests')
        .update({'status': ConsultationStatus.cancelled.name})
        .eq('id', id);
  }
}
