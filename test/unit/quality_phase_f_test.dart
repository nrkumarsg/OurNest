import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:our_nest/core/crypto/device_key_manager.dart';
import 'package:our_nest/core/crypto/media_crypto_service.dart';

Uint8List _bytes(int n) => Uint8List(n);

void main() {
  group('F38 – decrypted media cache has a size limit', () {
    test('evicts the least recently used item when over budget', () {
      final cache = DecryptedMediaCache(maxBytes: 100);
      cache.put('a', _bytes(40));
      cache.put('b', _bytes(40));
      expect(cache.get('a'), isNotNull); // a is now most recent
      cache.put('c', _bytes(40)); // 120 > 100 → evict b (least recent)
      expect(cache.get('b'), isNull);
      expect(cache.get('a'), isNotNull);
      expect(cache.get('c'), isNotNull);
      expect(cache.totalBytes, 80);
    });

    test('replacing a key does not double count', () {
      final cache = DecryptedMediaCache(maxBytes: 100);
      cache.put('a', _bytes(30));
      cache.put('a', _bytes(50));
      expect(cache.totalBytes, 50);
      expect(cache.length, 1);
    });

    test('an item bigger than the whole budget is not cached', () {
      final cache = DecryptedMediaCache(maxBytes: 100);
      cache.put('huge', _bytes(101));
      expect(cache.get('huge'), isNull);
      expect(cache.totalBytes, 0);
    });

    test('clear empties everything (used on sign-out)', () {
      final cache = DecryptedMediaCache(maxBytes: 100)..put('a', _bytes(10));
      cache.clear();
      expect(cache.length, 0);
      expect(cache.totalBytes, 0);
    });
  });

  group('F40 – real device platform is recorded', () {
    test('maps every platform', () {
      String name(TargetPlatform p, {bool web = false}) =>
          DeviceKeyManager.platformName(isWeb: web, platform: p);
      expect(name(TargetPlatform.android), 'android');
      expect(name(TargetPlatform.iOS), 'ios');
      expect(name(TargetPlatform.windows), 'windows');
      expect(name(TargetPlatform.macOS), 'macos');
      expect(name(TargetPlatform.linux), 'linux');
      expect(name(TargetPlatform.android, web: true), 'web');
    });

    test('database allows the new platform values', () {
      final sql = File('supabase/migrations/20261105000010_device_platforms.sql')
          .readAsStringSync();
      for (final p in ['android', 'ios', 'web', 'windows', 'macos', 'linux']) {
        expect(sql, contains("'$p'"));
      }
    });
  });

  group('F30 – SQL tests are safe and really use RLS', () {
    test('new security tests run as authenticated and always roll back', () {
      final sql =
          File('supabase/tests/security_rules_tests.sql').readAsStringSync();
      expect(sql, contains("set_config('role', 'authenticated', true)"));
      expect(sql.trimRight().endsWith('rollback;'), isTrue);
      expect(sql, contains('ournest.allow_test_data'));
    });

    test('old destructive tests refuse to run without the opt-in flag', () {
      for (final f in [
        'supabase/tests/family_rls_tests.sql',
        'supabase/tests/chat_rls_tests.sql',
      ]) {
        final sql = File(f).readAsStringSync();
        expect(sql.indexOf('ournest.allow_test_data'),
            lessThan(sql.indexOf('delete from')),
            reason: '$f must check the flag before deleting anything');
      }
    });
  });

  group('Migrations', () {
    test('migration files are uniquely numbered and in order', () {
      final names = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.sql'))
          .toList()
        ..sort();
      final stamps = names.map((n) => n.split('_').first).toList();
      expect(stamps.toSet().length, stamps.length, reason: 'duplicate timestamps');
      expect(names.last, startsWith('20261105000010'));
    });
  });
}
