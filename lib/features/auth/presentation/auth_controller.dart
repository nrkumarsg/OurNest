import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  StreamSubscription<sb.AuthState>? _authSub;

  AuthController(this._repository)
      : super(AuthState(
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
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: sessionUser,
          email: sessionUser.email ?? state.email,
          errorMessage: null,
        );
      } else if (data.event == sb.AuthChangeEvent.signedOut) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Attempts instant 1-tap sign-in first; falls back to Email OTP / Magic Link if required
  Future<bool> sendOtp(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final signedInUser =
          await _repository.signInInstantOrSendEmail(cleanEmail);
      final activeUser = signedInUser ?? _repository.currentUser;
      if (activeUser != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: activeUser,
          email: activeUser.email ?? cleanEmail,
          errorMessage: null,
        );
        return true;
      }
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

  /// Signs out
  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repository.signOut();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyError(e));
    }
  }

  String _friendlyError(Object e) {
    if (e is sb.AuthException) {
      return e.message;
    }
    return e.toString();
  }
}
