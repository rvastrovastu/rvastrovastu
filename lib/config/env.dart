class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const aiApiBaseUrl = String.fromEnvironment(
    'AI_API_BASE_URL',
    defaultValue: '',
  );
}
