import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

/// Turns an error into a sentence a family member can understand.
///
/// `error.toString()` used to be shown directly, giving texts like
/// "Bad state: …" or "PostgrestException(message: …, code: P0001)".
String friendlyError(Object? error, {String? fallback}) {
  const generic =
      'Something went wrong. Please check your connection and try again.';
  if (error is StateError) return error.message;
  if (error is AuthException) return error.message;
  if (error is PostgrestException) {
    // P0001 = message raised on purpose by our database functions.
    if (error.code == 'P0001') return error.message;
    if (error.code == '42501') return 'You are not allowed to do this.';
    return fallback ?? generic;
  }
  return fallback ?? generic;
}
