import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_initialization.dart';

/// How many questions the user may still ask.
class AiAllowance {
  final bool premium;
  final int limit;
  final int used;
  final int remaining;

  const AiAllowance({
    required this.premium,
    required this.limit,
    required this.used,
    required this.remaining,
  });

  factory AiAllowance.fromJson(Map<String, dynamic> json) => AiAllowance(
    premium: json['premium'] == true,
    limit: (json['limit'] as num?)?.toInt() ?? 0,
    used: (json['used'] as num?)?.toInt() ?? 0,
    remaining: (json['remaining'] as num?)?.toInt() ?? 0,
  );
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
