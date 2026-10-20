import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'supabase_config.dart';

class AppInitialization {
  static Future<void> initialize() async {
    // Initialize the IANA timezone database before any
    // timezone-aware astrology or Panchang calculations.
    tz.initializeTimeZones();

    if (!SupabaseConfig.isConfigured) {
      return;
    }

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }

  static bool get supabaseAvailable {
    return SupabaseConfig.isConfigured;
  }

  static SupabaseClient get supabase {
    return Supabase.instance.client;
  }
}
