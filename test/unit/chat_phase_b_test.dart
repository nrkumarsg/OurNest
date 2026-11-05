import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:our_nest/features/chat/data/chat_repository.dart';
import 'package:our_nest/features/chat/domain/message_payload.dart';
import 'package:our_nest/features/chat/domain/thread_filter.dart';

void main() {
  const me = 'me';
  const dad = 'dad';
  const mom = 'mom';

  group('F22 – messages land in the right thread', () {
    test('message to everyone is in the family thread only', () {
      expect(
          ThreadFilter.belongsInFamilyThread(
              audience: 'all', recipientIds: '$me,$dad,$mom'),
          isTrue);
      expect(
          ThreadFilter.belongsInDirectThread(
              audience: 'all',
              senderId: me,
              recipientIds: '$me,$dad,$mom',
              myUserId: me,
              otherUserId: dad),
          isFalse);
    });

    test('1-to-1 message to Dad shows in the Dad thread, not the Mom thread',
        () {
      bool inThread(String other) => ThreadFilter.belongsInDirectThread(
          audience: 'selected',
          senderId: me,
          recipientIds: '$me,$dad',
          myUserId: me,
          otherUserId: other);
      expect(inThread(dad), isTrue);
      expect(inThread(mom), isFalse);
      expect(
          ThreadFilter.belongsInFamilyThread(
              audience: 'selected', recipientIds: '$me,$dad'),
          isFalse);
    });

    test('"selected" group message (3 people) shows in the family thread', () {
      expect(
          ThreadFilter.belongsInFamilyThread(
              audience: 'selected', recipientIds: '$me,$dad,$mom'),
          isTrue);
      expect(
          ThreadFilter.belongsInDirectThread(
              audience: 'selected',
              senderId: dad,
              recipientIds: '$me,$dad,$mom',
              myUserId: me,
              otherUserId: dad),
          isFalse);
    });

    test('legacy message without recipient list falls back to sender', () {
      expect(
          ThreadFilter.belongsInDirectThread(
              audience: 'selected',
              senderId: dad,
              recipientIds: null,
              myUserId: me,
              otherUserId: dad),
          isTrue);
      expect(
          ThreadFilter.belongsInDirectThread(
              audience: 'selected',
              senderId: dad,
              recipientIds: '',
              myUserId: me,
              otherUserId: mom),
          isFalse);
    });

    test('recipient parsing ignores blanks, spaces and duplicates', () {
      expect(ThreadFilter.parseRecipients(' a, b,,a ,'), {'a', 'b'});
      expect(ThreadFilter.parseRecipients(null), isEmpty);
    });
  });

  group('Encrypted payload carries the recipient list', () {
    test('round-trips recipients', () {
      const p = MessagePayload(text: 'hi', recipientIds: [me, dad]);
      final back = MessagePayload.fromDecryptedJson(p.toEncodedJson());
      expect(back.recipientIds, [me, dad]);
      expect(back.text, 'hi');
    });

    test('older payloads without recipients still parse', () {
      final back = MessagePayload.fromDecryptedJson('{"text":"old"}');
      expect(back.recipientIds, isNull);
      expect(back.text, 'old');
    });
  });

  group('F24 – read receipts are batched', () {
    test('reads batched ids and legacy single id', () {
      expect(
          ChatRepository.ackMessageIds({
            'message_ids': ['a', 'b'],
            'message_id': 'b',
          }),
          {'a', 'b'});
      expect(ChatRepository.ackMessageIds({'message_id': 'x'}), {'x'});
      expect(ChatRepository.ackMessageIds({'other': 1}), isEmpty);
    });

    test('chat screen no longer sends one broadcast per message', () {
      final src = File('lib/features/chat/data/chat_repository.dart')
          .readAsStringSync();
      expect(src, contains("'message_ids': fresh"));
      expect(src, contains('_readAckSent'));
    });
  });

  group('F02 / F03 – sync and atomic send', () {
    late String repo;
    late String sql;
    setUpAll(() {
      repo = File('lib/features/chat/data/chat_repository.dart')
          .readAsStringSync();
      sql = File('supabase/migrations/20261105000006_atomic_send_message.sql')
          .readAsStringSync();
    });

    test('app sends through the atomic send_message RPC', () {
      expect(repo, contains("rpc('send_message'"));
      // Fallback only when the RPC is missing, never on other errors.
      expect(repo, contains("e.code != 'PGRST202'"));
    });

    test('RPC inserts message, recipients and keys in one function', () {
      expect(sql, contains('insert into public.messages'));
      expect(sql, contains('insert into public.message_recipients'));
      expect(sql, contains('insert into public.message_keys'));
      expect(sql, contains('security invoker'));
    });

    test('catch-up sync runs whenever the realtime channel (re)connects', () {
      expect(repo, contains('RealtimeSubscribeStatus.subscribed'));
      expect(repo, contains('_safeSync(familyId)'));
      expect(repo, contains('Future<int> syncMissedMessages'));
    });

    test('own messages from another device are no longer ignored', () {
      expect(repo.contains('if (senderId == currentUserId) return;'), isFalse);
    });
  });

  group('F23 – failed sends are not silent', () {
    test('chat screen checks every send result', () {
      final src = File('lib/features/chat/presentation/chat_screen.dart')
          .readAsStringSync();
      final sends = RegExp(r'chatControllerProvider\.notifier\)\s*\.send')
          .allMatches(src)
          .length;
      final checked =
          RegExp(r'final ok = await ref').allMatches(src).length;
      expect(sends, greaterThan(0));
      expect(checked, sends);
      expect(src, contains('_showSendError()'));
    });
  });
}
