import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});

/// Email OTP / magic-link authentication only.
///
/// SECURITY: there is intentionally no password-based sign-in. A previous
/// version derived every user's password from their email address, which let
/// anyone who knew an email address sign in as that user (audit finding F01).
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Basic shape check so we don't call Supabase with obviously bad input.
  static bool isValidEmail(String email) {
    final clean = email.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(clean);
  }

  /// Sends a one-time 6-digit code and sign-in link to the given email address.
  Future<void> sendEmailOtp(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!isValidEmail(cleanEmail)) {
      throw const AuthException('Please enter a valid email address.');
    }
    final redirectUrl = kIsWeb
        ? '${Uri.base.origin}${Uri.base.path.startsWith('/app') ? '/app/' : '/'}'
        : 'ournest://login-callback';
    await _client.auth.signInWithOtp(
      email: cleanEmail,
      shouldCreateUser: true,
      emailRedirectTo: redirectUrl,
    );
  }

  /// Verifies either:
  /// 1. The 6-digit OTP code (`123456`), OR
  /// 2. The full "Sign in" Magic Link URL (`https://.../auth/v1/verify?token=...&type=magiclink`)
  ///    if the Supabase email template sent a Magic Link instead of `{{ .Token }}`.
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String otpCode,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final rawInput = otpCode.trim();

    // Check if the user pasted the full "Sign in" URL from their email
    if (rawInput.startsWith('http://') ||
        rawInput.startsWith('https://') ||
        rawInput.contains('token=')) {
      final uri = Uri.tryParse(rawInput);
      final tokenHash =
          uri?.queryParameters['token'] ?? uri?.queryParameters['token_hash'];
      final typeParam = uri?.queryParameters['type']?.toLowerCase();

      if (tokenHash != null && tokenHash.isNotEmpty) {
        final preferredType = typeParam == 'signup'
            ? OtpType.signup
            : (typeParam == 'email' ? OtpType.email : OtpType.magiclink);
        try {
          return await _client.auth.verifyOTP(
            tokenHash: tokenHash,
            type: preferredType,
          );
        } on AuthException catch (_) {
          try {
            return await _client.auth.verifyOTP(
              tokenHash: tokenHash,
              type: OtpType.magiclink,
            );
          } on AuthException catch (_) {
            return await _client.auth.verifyOTP(
              tokenHash: tokenHash,
              type: OtpType.signup,
            );
          }
        }
      }
    }

    try {
      return await _client.auth.verifyOTP(
        email: cleanEmail,
        token: rawInput,
        type: OtpType.email,
      );
    } on AuthException catch (_) {
      try {
        return await _client.auth.verifyOTP(
          email: cleanEmail,
          token: rawInput,
          type: OtpType.signup,
        );
      } on AuthException catch (_) {
        return await _client.auth.verifyOTP(
          email: cleanEmail,
          token: rawInput,
          type: OtpType.magiclink,
        );
      }
    }
  }

  /// Resends a fresh dynamic OTP to the same email address.
  Future<void> resendEmailOtp(String email) async {
    await sendEmailOtp(email);
  }

  /// Signs the user out (this device only).
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
