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

  /// Inserts or updates the user's profile.
  ///
  /// Audit F10: this used to try three fallbacks and, if all failed, return
  /// the unsaved profile as if it had been saved. It also silently dropped the
  /// phone number when it clashed with another account. Now it either saves
  /// everything or throws a clear error.
  Future<Profile> upsertProfile(Profile profile) async {
    try {
      final response = await _client
          .from('profiles')
          .upsert(profile.toJson())
          .select()
          .single();
      return Profile.fromJson(response);
    } on PostgrestException catch (e) {
      throw StateError(friendlyProfileError(e.code, e.message));
    }
  }

  /// Turns database errors into words a family member understands.
  static String friendlyProfileError(String? code, String message) {
    if (code == '23505' && message.contains('phone')) {
      return 'This phone number is already used by another OurNest account.';
    }
    if (code == '23514') {
      return 'One of the details has an invalid value. Please check and try again.';
    }
    if (code == '42501') {
      return 'You are not allowed to change this profile.';
    }
    return 'Could not save your profile. Please check your connection and try again.';
  }
}
