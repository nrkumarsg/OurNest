import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment variable reader for Supabase URL and keys.
class Env {
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Fallback if .env is missing or not packaged in test runners
    }
  }

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://lbpboiyyhqyheajgrjlw.supabase.co';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxicGJvaXl5aHF5aGVhamdyamx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM2MjcyMjUsImV4cCI6MjEwOTIwMzIyNX0.y5MlGRy6HtmPVaItX4RfnNwtlqc5cHVt0Nv6jhfl-Dg';

  static String get appEnv => dotenv.env['APP_ENV'] ?? 'production';
}
