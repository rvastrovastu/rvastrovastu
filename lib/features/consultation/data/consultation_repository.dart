import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_initialization.dart';
import '../domain/consultation.dart';

/// The server side isn't ready: Supabase isn't configured in this build,
/// or the consultations table / payment function hasn't been deployed.
class ConsultationNotSetUp implements Exception {
  final Object? cause;

  const ConsultationNotSetUp([this.cause]);

  @override
  String toString() => 'ConsultationNotSetUp($cause)';
}

/// There is no session and a guest session couldn't be started, so the
/// user has to sign in first.
class ConsultationNeedsSignIn implements Exception {
  const ConsultationNeedsSignIn();
}

/// Thrown when someone else booked the same slot first.
class ConsultationSlotTaken implements Exception {
  const ConsultationSlotTaken();
}

/// Booking requests in Supabase (`consultation_requests`). Each user sees
/// only their own; booked slots come from `consultation_taken_slots`, and
/// payment links from the `create-consultation-checkout` function.
class ConsultationRepository {
  static const checkoutFunction = 'create-consultation-checkout';

  const ConsultationRepository();

  /// A client with a session, starting a guest session when there is
  /// none.
  Future<SupabaseClient> _client() async {
    if (!AppInitialization.supabaseAvailable) {
      throw const ConsultationNotSetUp('Supabase is not configured');
    }
    final client = AppInitialization.supabase;
    if (client.auth.currentSession == null) {
      try {
        await client.auth.signInAnonymously();
      } catch (error) {
        debugPrint('[CONSULT] guest sign-in failed: $error');
      }
    }
    if (client.auth.currentSession == null) {
      throw const ConsultationNeedsSignIn();
    }
    return client;
  }

  /// Turns "the table or function isn't there" into [ConsultationNotSetUp].
  static Never _rethrow(Object error, StackTrace stack) {
    debugPrint('[CONSULT] $error');
    if (error is PostgrestException) {
      const missing = {'PGRST205', 'PGRST202', '42P01', '42883', 'PGRST204'};
      if (error.code == '23505') throw const ConsultationSlotTaken();
      if (missing.contains(error.code)) throw ConsultationNotSetUp(error);
    }
    if (error is FunctionException && error.status == 404) {
      throw ConsultationNotSetUp(error);
    }
    Error.throwWithStackTrace(error, stack);
  }

  Future<ConsultationRequest> submit(ConsultationRequest request) async {
    final client = await _client();
    try {
      final row = await client
          .from('consultation_requests')
          .insert(request.toInsert())
          .select()
          .single();
      return ConsultationRequest.fromRow(row);
    } catch (error, stack) {
      _rethrow(error, stack);
    }
  }

  Future<List<ConsultationRequest>> mine() async {
    final SupabaseClient client;
    try {
      client = await _client();
    } on ConsultationNeedsSignIn {
      return const [];
    }
    try {
      final rows = await client
          .from('consultation_requests')
          .select()
          .order('slot_start', ascending: false)
          .limit(50);
      return [for (final row in rows) ConsultationRequest.fromRow(row)];
    } catch (error, stack) {
      _rethrow(error, stack);
    }
  }

  /// Start times already held by someone (requested, confirmed or paid).
  Future<Set<DateTime>> takenSlots(DateTime from, DateTime to) async {
    final client = await _client();
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
    final client = await _client();
    try {
      await client
          .from('consultation_requests')
          .update({'status': ConsultationStatus.cancelled.name})
          .eq('id', id);
    } catch (error, stack) {
      _rethrow(error, stack);
    }
  }

  /// A Stripe Checkout page for a confirmed booking.
  Future<Uri> checkoutUrl(String id) async {
    final client = await _client();
    try {
      final res = await client.functions.invoke(
        checkoutFunction,
        body: {'request_id': id},
      );
      final url = (res.data as Map?)?['url'] as String?;
      if (url == null) throw StateError('No checkout URL in ${res.data}');
      return Uri.parse(url);
    } catch (error, stack) {
      _rethrow(error, stack);
    }
  }
}
