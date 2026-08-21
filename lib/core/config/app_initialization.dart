import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class AppInitialization {
  static Future<void> initialize() async {
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
