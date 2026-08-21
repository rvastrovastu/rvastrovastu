class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const astrologyApiBaseUrl = String.fromEnvironment(
    'ASTROLOGY_API_BASE_URL',
    defaultValue: '',
  );

  static const astrologyApiKey = String.fromEnvironment(
    'ASTROLOGY_API_KEY',
    defaultValue: '',
  );

  static const aiApiBaseUrl = String.fromEnvironment(
    'AI_API_BASE_URL',
    defaultValue: '',
  );
}
