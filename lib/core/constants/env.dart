/// Build-time configuration (audit F28 / F33).
///
/// Values come from `--dart-define` (or `--dart-define-from-file`), so no
/// `.env` file is bundled into the web app, the Windows zip or the APK any
/// more. Example for a staging build:
///
///   flutter build apk --dart-define-from-file=env/staging.json
///
/// When nothing is passed, the production project's PUBLIC values are used.
/// The anon key is designed to be public (access is controlled by Row Level
/// Security); never put a service-role key or other secret here.
class Env {
  Env._();

  static const _defaultSupabaseUrl = 'https://lbpboiyyhqyheajgrjlw.supabase.co';
  static const _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxicGJvaXl5aHF5aGVhamdyamx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM2MjcyMjUsImV4cCI6MjEwOTIwMzIyNX0.y5MlGRy6HtmPVaItX4RfnNwtlqc5cHVt0Nv6jhfl-Dg';

  static const supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultSupabaseUrl);

  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
      defaultValue: _defaultSupabaseAnonKey);

  static const appEnv =
      String.fromEnvironment('APP_ENV', defaultValue: 'production');

  /// True when this build talks to the production database.
  static bool get isProductionProject => supabaseUrl == _defaultSupabaseUrl;
}
