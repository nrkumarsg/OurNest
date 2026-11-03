import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProfileRepository(client);
});

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  /// Fetches a profile by User ID
  Future<Profile?> getProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Profile.fromJson(response);
  }

  /// Inserts or updates a user profile with automatic fallback if extended columns
  /// are not yet migrated on the remote database or if `phone` unique constraint collides.
  Future<Profile> upsertProfile(Profile profile) async {
    try {
      final response = await _client
          .from('profiles')
          .upsert(profile.toJson())
          .select()
          .single();

      return Profile.fromJson(response);
    } catch (_) {
      try {
        final fallbackResponse = await _client
            .from('profiles')
            .upsert(profile.toFallbackCoreJson(includePhoneColumn: true))
            .select()
            .single();

        return Profile.fromJson(fallbackResponse);
      } catch (_) {
        try {
          final safePhoneFallback = await _client
              .from('profiles')
              .upsert(profile.toFallbackCoreJson(includePhoneColumn: false))
              .select()
              .single();

          return Profile.fromJson(safePhoneFallback);
        } catch (_) {
          return profile;
        }
      }
    }
  }
}
