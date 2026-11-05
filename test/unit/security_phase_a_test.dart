import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:our_nest/core/crypto/device_key_manager.dart';
import 'package:our_nest/features/auth/data/auth_repository.dart';
import 'package:our_nest/features/auth/domain/auth_state.dart';
import 'package:our_nest/features/auth/presentation/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Minimal fake so AuthController can be tested without a real Supabase.
class _FakeAuthRepository implements AuthRepository {
  final _changes = StreamController<sb.AuthState>.broadcast();
  int signOutCalls = 0;
  String? lastOtpEmail;

  @override
  sb.User? get currentUser => null;

  @override
  Stream<sb.AuthState> get authStateChanges => _changes.stream;

  @override
  Future<void> sendEmailOtp(String email) async => lastOtpEmail = email;

  @override
  Future<void> resendEmailOtp(String email) => sendEmailOtp(email);

  @override
  Future<sb.AuthResponse> verifyEmailOtp(
          {required String email, required String otpCode}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async => signOutCalls++;
}

void main() {
  group('F01 – no guessable password login', () {
    test('auth repository contains no password-based sign-in', () {
      final src =
          File('lib/features/auth/data/auth_repository.dart').readAsStringSync();
      expect(src.contains('signInWithPassword'), isFalse);
      expect(src.contains('OurNest#Family'), isFalse);
      expect(src.contains('UserAttributes(password'), isFalse);
    });

    test('no source file contains the old derived-password prefix', () {
      final hits = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('OurNest#Family2026'))
          .map((f) => f.path)
          .toList();
      expect(hits, isEmpty);
    });

    test('sendOtp only sends a code and never reports "authenticated"',
        () async {
      final repo = _FakeAuthRepository();
      final controller = AuthController(repo);
      final ok = await controller.sendOtp('  Amma@Example.com ');
      expect(ok, isTrue);
      expect(repo.lastOtpEmail, 'amma@example.com');
      expect(controller.state.status, AuthStatus.otpSent);
      expect(controller.state.user, isNull);
      controller.dispose();
    });

    test('email validation rejects obvious bad input', () {
      expect(AuthRepository.isValidEmail('amma@example.com'), isTrue);
      expect(AuthRepository.isValidEmail(''), isFalse);
      expect(AuthRepository.isValidEmail('amma'), isFalse);
      expect(AuthRepository.isValidEmail('amma@'), isFalse);
      expect(AuthRepository.isValidEmail('a b@example.com'), isFalse);
    });
  });

  group('F11 – shared phone privacy', () {
    test('device key storage names are different for each user', () {
      final a = DeviceKeyStorageNames.forUser('user-a');
      final b = DeviceKeyStorageNames.forUser('user-b');
      expect(a.privateKey, isNot(b.privateKey));
      expect(a.publicKey, isNot(b.publicKey));
      expect(a.deviceId, isNot(b.deviceId));
      expect(a.privateKey, contains('user-a'));
    });

    test('signOut wipes local data before signing out', () async {
      final repo = _FakeAuthRepository();
      final calls = <String>[];
      final controller = AuthController(
        repo,
        cleanupLocalSession: () async => calls.add('cleanup'),
      );

      await controller.signOut();

      expect(calls, ['cleanup']);
      expect(repo.signOutCalls, 1);
      expect(controller.state.status, AuthStatus.unauthenticated);
      controller.dispose();
    });

    test('signOut still completes when cleanup throws', () async {
      final repo = _FakeAuthRepository();
      final controller = AuthController(
        repo,
        cleanupLocalSession: () async => throw StateError('disk busy'),
      );

      await controller.signOut();

      expect(repo.signOutCalls, 1);
      expect(controller.state.status, AuthStatus.unauthenticated);
      controller.dispose();
    });
  });

  group('F15 – chat is not shown over the lock screen', () {
    test('main activity manifest has no showWhenLocked / turnScreenOn', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest.contains('android:showWhenLocked="true"'), isFalse);
      expect(manifest.contains('android:turnScreenOn="true"'), isFalse);
    });

    test('MainActivity only allows lock-screen display for alarm payloads', () {
      final kt = File(
              'android/app/src/main/kotlin/com/ournest/app/MainActivity.kt')
          .readAsStringSync();
      expect(kt, contains('alarm_ring:'));
      expect(kt, contains('alarm_escalate:'));
      expect(kt, contains('setShowWhenLocked(isAlarm)'));
    });

    test('alarm payload prefixes still match the scheduler', () {
      final scheduler = File('lib/core/platform/alarm_scheduler_service.dart')
          .readAsStringSync();
      expect(scheduler, contains("payload: 'alarm_ring:"));
      expect(scheduler, contains("payload: 'alarm_escalate:"));
    });
  });

  group('F12 / F18 / F19 – database hardening migration', () {
    late String sql;
    setUpAll(() {
      sql = File('supabase/migrations/20261105000005_security_hardening.sql')
          .readAsStringSync();
    });

    test('link requests can only be inserted as pending', () {
      expect(sql, contains("and status = 'pending'"));
    });

    test('only the target family admin can change link status', () {
      expect(sql, contains('guard_family_link_update'));
      expect(sql, contains('is_family_admin(old.target_family_id)'));
    });

    test('recipients and keys are limited to the message family', () {
      expect(sql, contains('user_is_active_member(m.family_id'));
      expect(sql, contains('device_is_message_recipient(message_id'));
    });

    test('every security definer function pins search_path', () {
      for (final fn in [
        'is_active_member(uuid)',
        'is_family_admin(uuid)',
        'shares_family_with(uuid)',
        'are_families_linked(uuid, uuid)',
        'request_family_link(uuid, text, text, text)',
      ]) {
        expect(sql, contains('alter function public.$fn'),
            reason: '$fn must have search_path pinned');
      }
    });
  });
}
