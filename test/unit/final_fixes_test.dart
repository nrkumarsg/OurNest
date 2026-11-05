import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:our_nest/features/chat/domain/message_payload.dart';
import 'package:our_nest/features/share/share_intake.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  group('F44 – sharing into OurNest', () {
    test('shared link or text becomes the pre-filled message', () {
      final share = PendingShare.fromMedia([
        SharedMediaFile(path: 'https://youtu.be/abc', type: SharedMediaType.url),
      ]);
      expect(share.text, 'https://youtu.be/abc');
      expect(share.imagePaths, isEmpty);
      expect(share.isEmpty, isFalse);
    });

    test('shared photos are collected with their caption', () {
      final share = PendingShare.fromMedia([
        SharedMediaFile(
            path: '/tmp/a.jpg', type: SharedMediaType.image, message: 'Trip!'),
        SharedMediaFile(path: '/tmp/b.png', type: SharedMediaType.image),
      ]);
      expect(share.imagePaths, ['/tmp/a.jpg', '/tmp/b.png']);
      expect(share.text, 'Trip!');
    });

    test('at most 10 photos per share; videos/files ignored', () {
      final share = PendingShare.fromMedia([
        for (var i = 0; i < 15; i++)
          SharedMediaFile(path: '/p$i.jpg', type: SharedMediaType.image),
        SharedMediaFile(path: '/v.mp4', type: SharedMediaType.video),
        SharedMediaFile(path: '/f.pdf', type: SharedMediaType.file),
      ]);
      expect(share.imagePaths.length, PendingShare.maxImages);
      expect(share.imagePaths.contains('/v.mp4'), isFalse);
    });

    test('nothing usable gives an empty share', () {
      expect(PendingShare.fromMedia([]).isEmpty, isTrue);
      expect(
          PendingShare.fromMedia([
            SharedMediaFile(path: '  ', type: SharedMediaType.text),
          ]).isEmpty,
          isTrue);
    });

    test('app, splash and family chat are wired to the share', () {
      final app = File('lib/app.dart').readAsStringSync();
      expect(app, contains('ShareIntake.start('));
      final splash = File('lib/features/auth/presentation/splash_screen.dart')
          .readAsStringSync();
      expect(splash, contains('pendingShareProvider'));
      final chat = File('lib/features/chat/presentation/chat_screen.dart')
          .readAsStringSync();
      expect(chat, contains('_consumePendingShare'));
    });
  });

  group('F37 – replies keep the real message ID', () {
    test('payload carries both the quote and the ID', () {
      const p = MessagePayload(
          text: 'yes', replyToId: 'Amma: Had food?', replyToMessageId: 'm-42');
      final back = MessagePayload.fromDecryptedJson(p.toEncodedJson());
      expect(back.replyToId, 'Amma: Had food?');
      expect(back.replyToMessageId, 'm-42');
    });

    test('older replies without an ID still parse', () {
      final back =
          MessagePayload.fromDecryptedJson('{"text":"ok","reply_to":"Dad: hi"}');
      expect(back.replyToId, 'Dad: hi');
      expect(back.replyToMessageId, isNull);
    });
  });

  group('F31 – startup failures are visible', () {
    test('Supabase init reports failure and main shows a retry screen', () {
      final client =
          File('lib/core/network/supabase_client.dart').readAsStringSync();
      expect(client, contains('static Future<bool> init()'));
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('StartupErrorApp'));
      expect(main, contains('PlatformDispatcher.instance.onError'));
      expect(main.contains('catch (_) {}'), isFalse);
    });
  });

  group('F39 – family screen split into smaller files', () {
    test('no single family screen file is over 1,500 lines', () {
      for (final f in [
        'family_screen.dart',
        'family_screen_link_sheets.dart',
        'family_screen_tabs.dart',
      ]) {
        final lines = File('lib/features/family/presentation/$f')
            .readAsLinesSync()
            .length;
        expect(lines, lessThan(1500), reason: f);
      }
    });
  });

  group('F42 – repeatable release build', () {
    test('release script rebuilds site files and blocks a bundled .env', () {
      final ps = File('scripts/build_release.ps1').readAsStringSync();
      expect(ps, contains('--base-href /app/'));
      expect(ps, contains('OurNest-Windows-Desktop.zip'));
      expect(ps, contains('landing/ournest.apk'));
      expect(ps, contains('-Filter ".env"'));
      expect(ps, contains('flutter test'));
    });

    test('APK download name is no longer tied to an old version', () {
      final toml = File('netlify.toml').readAsStringSync();
      expect(toml, contains('filename=\\"OurNest.apk\\"'));
    });
  });
}
