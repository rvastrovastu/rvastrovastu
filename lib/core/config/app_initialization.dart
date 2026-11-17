import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'supabase_config.dart';

class AppInitialization {
  static bool _supabaseReady = false;

  static Future<void> initialize() async {
    // Initialize the IANA timezone database before any
    // timezone-aware astrology or Panchang calculations.
    tz.initializeTimeZones();

    if (!SupabaseConfig.isConfigured) {
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      _supabaseReady = true;
    } catch (_) {
      // Keep the app usable offline or when the backend is unreachable.
      _supabaseReady = false;
    }
  }

  /// True only once Supabase has actually initialized, so callers never touch
  /// `Supabase.instance` before it exists.
  static bool get supabaseAvailable {
    return SupabaseConfig.isConfigured && _supabaseReady;
  }

  static SupabaseClient get supabase {
    return Supabase.instance.client;
  }
}
