import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:our_nest/core/errors/friendly_error.dart';
import 'package:our_nest/core/router/route_guard.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

String? _redirect(String location, {required bool loggedIn}) =>
    RouteGuard.redirect(Uri.parse(location), loggedIn: loggedIn);

void main() {
  setUp(() => RouteGuard.pendingJoinLocation = null);

  group('F26 – route guard', () {
    test('signed-out users are sent to login for protected screens', () {
      for (final p in ['/home', '/family', '/settings', '/chat/family']) {
        expect(_redirect(p, loggedIn: false), '/phone-login', reason: p);
      }
    });

    test('login screens stay reachable when signed out', () {
      for (final p in ['/', '/phone-login', '/otp-verify']) {
        expect(_redirect(p, loggedIn: false), isNull, reason: p);
      }
    });

    test('signed-in users are not redirected from normal screens', () {
      expect(_redirect('/home', loggedIn: true), isNull);
      expect(_redirect('/chat/family', loggedIn: true), isNull);
    });
  });

  group('F26 – invite deep links', () {
    test('ournest://invite/CODE opens the join screen', () {
      final to = _redirect('ournest://invite/ABC234?name=N.R.K%20Family',
          loggedIn: true)!;
      final uri = Uri.parse(to);
      expect(uri.path, '/join-family');
      expect(uri.queryParameters['code'], 'ABC234');
      expect(uri.queryParameters['name'], 'N.R.K Family');
    });

    test('path-only form "/CODE" (some Flutter versions) also works', () {
      final to = Uri.parse(_redirect('/ABC234', loggedIn: true)!);
      expect(to.path, '/join-family');
      expect(to.queryParameters['code'], 'ABC234');
    });

    test('https …/join?code= links work', () {
      final to = Uri.parse(
          _redirect('https://ournest.app/join?code=abc234', loggedIn: true)!);
      expect(to.queryParameters['code'], 'ABC234');
    });

    test('invite opened while signed out resumes after sign-in', () {
      expect(_redirect('ournest://invite/ABC234', loggedIn: false),
          '/phone-login');
      expect(RouteGuard.pendingJoinLocation, contains('code=ABC234'));

      // After sign-in the splash sends a user without a family to
      // /family-entry – the guard resumes the join instead.
      final resumed = _redirect('/family-entry', loggedIn: true)!;
      expect(Uri.parse(resumed).queryParameters['code'], 'ABC234');
      expect(RouteGuard.pendingJoinLocation, isNull);
    });

    test('email sign-in callback never lands on an unknown page', () {
      expect(_redirect('ournest://login-callback?code=x', loggedIn: false),
          '/otp-verify');
      expect(_redirect('ournest://login-callback?code=x', loggedIn: true), '/');
    });

    test('ordinary paths are not mistaken for invites', () {
      expect(_redirect('/family', loggedIn: true), isNull);
      expect(_redirect('/settings', loggedIn: true), isNull);
    });
  });

  group('Friendly errors', () {
    test('messages raised by our database functions are shown as-is', () {
      expect(
          friendlyError(const PostgrestException(
              message: 'You are the only admin.', code: 'P0001')),
          'You are the only admin.');
    });

    test('technical errors become plain language', () {
      final msg = friendlyError(
          const PostgrestException(message: 'relation x', code: '42P01'));
      expect(msg, contains('Something went wrong'));
      expect(friendlyError(StateError('Choose a member')), 'Choose a member');
      expect(friendlyError(Exception('x'), fallback: 'Try again'), 'Try again');
    });
  });

  group('F14 / F27 – release config', () {
    test('release builds no longer use the debug key silently', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();
      expect(gradle, contains("rootProject.file('key.properties')"));
      expect(gradle, contains('Release signing key missing'));
      expect(gradle, contains('ournest.allowDebugSigning'));
    });

    test('key.properties and keystores stay out of git', () {
      final ignore = File('.gitignore').readAsStringSync();
      expect(ignore, contains('**/android/key.properties'));
      expect(ignore, contains('*.jks'));
    });

    test('iOS explains location use', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('NSLocationWhenInUseUsageDescription'));
    });

    test('Android hands deep links to the router', () {
      final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(m, contains('flutter_deeplinking_enabled'));
    });
  });

  group('F28 / F33 – config and desktop launcher', () {
    test('.env is no longer bundled into app builds', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('- .env'), isFalse);
      expect(pubspec.contains('flutter_dotenv'), isFalse);
      final env = File('lib/core/constants/env.dart').readAsStringSync();
      expect(env, contains("String.fromEnvironment('SUPABASE_URL'"));
      expect(env.toLowerCase().contains('service_role'), isFalse);
    });

    test('desktop launcher never opens a LAN machine over http', () {
      final bat = File('landing/Start-OurNest-Desktop.bat').readAsStringSync();
      expect(bat.contains('start "" msedge --app="http://192.168'), isFalse);
      expect(bat.contains('chrome --app="http://192.168'), isFalse);
      expect(bat, contains('127.0.0.1'));
    });
  });

  group('F20 / F21 / Q1 / Q4 – database rules', () {
    late String sql;
    setUpAll(() => sql =
        File('supabase/migrations/20261105000009_invites_membership_realtime.sql')
            .readAsStringSync());

    test('wrong invite codes are counted and limited', () {
      expect(sql, contains('recent_failures >= 10'));
      // Must RETURN (not raise) after recording, or the insert is rolled back.
      expect(sql, contains("return json_build_object('error'"));
    });

    test('admin can issue a new invite code', () {
      expect(sql, contains('function public.regenerate_invite_code'));
      expect(sql, contains('is_family_admin(target_family_id)'));
    });

    test('Q1: one family per person', () {
      expect(sql, contains('You are already a member of another family'));
    });

    test('Q4: last admin must hand over before leaving', () {
      expect(sql, contains('before delete on public.family_members'));
      expect(sql, contains('Make another member admin before leaving'));
    });

    test('F21: realtime family channel limited to active members', () {
      expect(sql, contains('on realtime.messages'));
      expect(sql, contains("family_id_from_topic(realtime.topic())"));
      final repo =
          File('lib/features/chat/data/chat_repository.dart').readAsStringSync();
      expect(repo, contains('RealtimeChannelConfig(private: private)'));
    });

    test('app shows the server reason for a wrong code', () {
      final repo =
          File('lib/features/family/data/family_repository.dart').readAsStringSync();
      expect(repo, contains("map['error']"));
    });
  });
}
