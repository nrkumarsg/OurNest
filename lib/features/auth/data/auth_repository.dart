import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  String _deriveInstantKey(String cleanEmail) {
    return 'OurNest#Family2026!$cleanEmail';
  }

  String _buildAliasEmail(String cleanEmail) {
    final parts = cleanEmail.split('@');
    if (parts.length != 2) return cleanEmail;
    final baseLocal = parts[0].split('+').first;
    return '$baseLocal+ournest@${parts[1]}';
  }

  /// Signs the user in immediately without waiting for any email or 6-digit code.
  /// Returns the authenticated [User] if instant sign-in/sign-up succeeded;
  /// returns null if it fell back to sending an email OTP.
  Future<User?> signInInstantOrSendEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final instantPassword = _deriveInstantKey(cleanEmail);
    final aliasEmail = _buildAliasEmail(cleanEmail);
    final aliasPassword = _deriveInstantKey(aliasEmail);

    // 1. Try instant sign-in with exact email
    try {
      final signInRes = await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: instantPassword,
      );
      if (signInRes.user != null) {
        return signInRes.user;
      }
    } catch (_) {}

    // 2. Try instant sign-in with +ournest alias (fast path for previously registered emails)
    if (aliasEmail != cleanEmail) {
      try {
        final aliasSignIn = await _client.auth.signInWithPassword(
          email: aliasEmail,
          password: aliasPassword,
        );
        if (aliasSignIn.user != null) {
          return aliasSignIn.user;
        }
      } catch (_) {}
    }

    // 3. Try instant sign-up for brand-new email
    try {
      final signUpRes = await _client.auth.signUp(
        email: cleanEmail,
        password: instantPassword,
      );
      if (signUpRes.session != null && signUpRes.user != null) {
        return signUpRes.user;
      }
    } catch (_) {}

    // 4. Try instant sign-up with +ournest alias
    if (aliasEmail != cleanEmail) {
      try {
        final aliasSignUp = await _client.auth.signUp(
          email: aliasEmail,
          password: aliasPassword,
        );
        if (aliasSignUp.session != null && aliasSignUp.user != null) {
          return aliasSignUp.user;
        }
      } catch (_) {}
    }

    // 5. Last-resort fallback
    await sendEmailOtp(cleanEmail);
    return _client.auth.currentUser;
  }

  /// Sends a dynamic one-time password (OTP) & login link to the given email address (100% free via Supabase).
  Future<void> sendEmailOtp(String email) async {
    final cleanEmail = email.trim().toLowerCase();
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
        AuthResponse res;
        try {
          res = await _client.auth.verifyOTP(
            tokenHash: tokenHash,
            type: preferredType,
          );
        } on AuthException catch (_) {
          try {
            res = await _client.auth.verifyOTP(
              tokenHash: tokenHash,
              type: OtpType.magiclink,
            );
          } on AuthException catch (_) {
            res = await _client.auth.verifyOTP(
              tokenHash: tokenHash,
              type: OtpType.signup,
            );
          }
        }
        await _bindInstantKeyAfterVerify(cleanEmail);
        return res;
      }
    }

    final cleanToken = rawInput;
    AuthResponse res;

    try {
      res = await _client.auth.verifyOTP(
        email: cleanEmail,
        token: cleanToken,
        type: OtpType.email,
      );
    } on AuthException catch (_) {
      try {
        res = await _client.auth.verifyOTP(
          email: cleanEmail,
          token: cleanToken,
          type: OtpType.signup,
        );
      } on AuthException catch (_) {
        res = await _client.auth.verifyOTP(
          email: cleanEmail,
          token: cleanToken,
          type: OtpType.magiclink,
        );
      }
    }
    await _bindInstantKeyAfterVerify(cleanEmail);
    return res;
  }

  Future<void> _bindInstantKeyAfterVerify(String cleanEmail) async {
    try {
      if (cleanEmail.isNotEmpty && _client.auth.currentUser != null) {
        await _client.auth.updateUser(
          UserAttributes(password: _deriveInstantKey(cleanEmail)),
        );
      }
    } catch (_) {}
  }

  /// Resends a fresh dynamic OTP to the same email address.
  Future<void> resendEmailOtp(String email) async {
    await sendEmailOtp(email);
  }

  /// Signs out the user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
