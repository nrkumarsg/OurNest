import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/env.dart';

/// Provider for the Supabase instance
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Initialization helper for Supabase
class SupabaseService {
  /// Returns true when the client is ready. Audit F31: errors used to be
  /// swallowed, and the app then crashed later at `Supabase.instance`.
  static Future<bool> init() async {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      return true;
    } catch (e, st) {
      debugPrint('Supabase init failed: $e $st');
      return false;
    }
  }
}
