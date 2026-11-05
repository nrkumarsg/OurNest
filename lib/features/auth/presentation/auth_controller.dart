import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/crypto/device_key_manager.dart';
import '../../../core/crypto/media_crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../chat/data/chat_repository.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

/// Wipes everything a signed-out user could leave behind on a shared device:
/// decrypted local messages, cached media, in-memory keys and realtime state.
typedef LocalSessionCleanup = Future<void> Function();

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(
    repository,
    cleanupLocalSession: () async {
      try {
        ref.read(chatRepositoryProvider).resetForSignOut();
      } catch (_) {}
      try {
        ref.read(mediaCryptoServiceProvider).clearCache();
      } catch (_) {}
      try {
        ref.read(deviceKeyManagerProvider).clearInMemory();
      } catch (_) {}
      await ref.read(appDatabaseProvider).clearAllMessages();
    },
  );
});

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final LocalSessionCleanup? _cleanupLocalSession;
  StreamSubscription<sb.AuthState>? _authSub;

  AuthController(this._repository, {LocalSessionCleanup? cleanupLocalSession})
      : _cleanupLocalSession = cleanupLocalSession,
        super(AuthState(
          status: _repository.currentUser != null
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated,
          user: _repository.currentUser,
          email: _repository.currentUser?.email,
        )) {
    _authSub = _repository.authStateChanges.listen((data) {
      final sessionUser = data.session?.user;
      if (sessionUser != null) {
        if (state.status == AuthStatus.authenticated &&
            state.user?.id == sessionUser.id) {
          return;
        }
        // A different account signed in on this device: drop the old one's data.
        final previousUserId = state.user?.id;
        if (previousUserId != null && previousUserId != sessionUser.id) {
          _runCleanup();
        }
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: sessionUser,
          email: sessionUser.email ?? state.email,
          errorMessage: null,
        );
      } else if (data.event == sb.AuthChangeEvent.signedOut) {
        // Covers session expiry / sign-out triggered outside signOut().
        _runCleanup();
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Sends a 6-digit Email OTP / Magic Link. The user must prove inbox access.
  Future<bool> sendOtp(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repository.sendEmailOtp(cleanEmail);
      state = state.copyWith(
        status: AuthStatus.otpSent,
        email: cleanEmail,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendlyError(e),
      );
      return false;
    }
  }

  /// Verifies dynamic 6-digit Email OTP code
  Future<bool> verifyOtp(String otpCode) async {
    final targetEmail = state.email;
    if (targetEmail == null || targetEmail.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Email address missing. Please restart login.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _repository.verifyEmailOtp(
        email: targetEmail,
        otpCode: otpCode,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: response.user,
        email: response.user?.email ?? targetEmail,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendlyError(e),
      );
      return false;
    }
  }

  /// Resends the Email OTP
  Future<bool> resendOtp() async {
    final targetEmail = state.email;
    if (targetEmail == null || targetEmail.isEmpty) return false;
    try {
      await _repository.resendEmailOtp(targetEmail);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyError(e));
      return false;
    }
  }

  /// Signs out and wipes this user's local data from the device.
  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);
    // Wipe first: even if the network sign-out fails, nothing private stays behind.
    await _runCleanup();
    try {
      await _repository.signOut();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyError(e));
    }
  }

  Future<void> _runCleanup() async {
    final cleanup = _cleanupLocalSession;
    if (cleanup == null) return;
    try {
      await cleanup();
    } catch (_) {
      // Best effort: never block sign-out on cleanup errors.
    }
  }

  String _friendlyError(Object e) {
    if (e is sb.AuthException) {
      return e.message;
    }
    return e.toString();
  }
}
