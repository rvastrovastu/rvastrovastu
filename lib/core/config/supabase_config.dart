class SupabaseConfig {
  /// `staging` in staging.json; production when not set.
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  /// A build that talks to the staging backend: marked on screen and kept
  /// out of analytics and crash reports.
  static bool get isStaging => environment == 'staging';

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://niajpfaxjtgtuqdkekzn.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_5NTwVm98qDB6cpT9z-PN7A_hjNJvC1S',
  );

  static bool get isConfigured {
    return url.isNotEmpty && publishableKey.isNotEmpty;
  }
}
