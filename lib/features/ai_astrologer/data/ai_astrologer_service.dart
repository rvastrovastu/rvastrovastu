import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_initialization.dart';

/// How many questions the user may still ask.
class AiAllowance {
  final bool premium;
  final int limit;
  final int used;

  /// Everything still available: free questions plus pack questions.
  final int remaining;

  /// Free questions left this month (Premium: today's fair-use allowance).
  final int freeRemaining;

  /// Questions left from bought packs; they never expire.
  final int packRemaining;

  const AiAllowance({
    required this.premium,
    required this.limit,
    required this.used,
    required this.remaining,
    int? freeRemaining,
    this.packRemaining = 0,
  }) : freeRemaining = freeRemaining ?? remaining;

  factory AiAllowance.fromJson(Map<String, dynamic> json) {
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    return AiAllowance(
      premium: json['premium'] == true,
      limit: read('limit'),
      used: read('used'),
      remaining: read('remaining'),
      freeRemaining: json['freeRemaining'] == null
          ? null
          : read('freeRemaining'),
      packRemaining: read('packRemaining'),
    );
  }
}

class AiAnswer {
  final String text;
  final AiAllowance allowance;

  const AiAnswer(this.text, this.allowance);
}

/// The free allowance (or Premium's daily fair-use cap) is used up.
class AiLimitReached implements Exception {
  final AiAllowance allowance;

  const AiLimitReached(this.allowance);
}

/// The service or both AI providers are unavailable right now.
class AiUnavailable implements Exception {
  final Object? cause;

  const AiUnavailable([this.cause]);
}

abstract class AiAstrologerService {
  Future<AiAllowance?> status();

  Future<AiAnswer> ask({
    required String question,
    required Map<String, Object?> chart,
    required List<({bool fromUser, String text})> history,
    required String language,
  });
}

/// Calls the `ask-astrologer` Supabase edge function, which holds the AI
/// keys and enforces the allowance.
class SupabaseAiAstrologerService implements AiAstrologerService {
  static const function = 'ask-astrologer';

  Future<SupabaseClient> _client() async {
    if (!AppInitialization.supabaseAvailable) throw const AiUnavailable();
    final client = AppInitialization.supabase;
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
    return client;
  }

  @override
  Future<AiAllowance?> status() async {
    try {
      final client = await _client();
      final res = await client.functions.invoke(
        function,
        body: {'action': 'status'},
      );
      return AiAllowance.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (error) {
      debugPrint('[AI] status failed: $error');
      return null;
    }
  }

  @override
  Future<AiAnswer> ask({
    required String question,
    required Map<String, Object?> chart,
    required List<({bool fromUser, String text})> history,
    required String language,
  }) async {
    final client = await _client();
    try {
      final res = await client.functions.invoke(
        function,
        body: {
          'question': question,
          'chart': chart,
          'language': language,
          'history': [
            for (final m in history)
              {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
          ],
        },
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      return AiAnswer(data['answer'] as String, AiAllowance.fromJson(data));
    } on FunctionException catch (error) {
      final details = error.details;
      if (error.status == 402 && details is Map) {
        throw AiLimitReached(
          AiAllowance.fromJson(Map<String, dynamic>.from(details)),
        );
      }
      throw AiUnavailable(error);
    } catch (error) {
      if (error is AiLimitReached || error is AiUnavailable) rethrow;
      throw AiUnavailable(error);
    }
  }
}
