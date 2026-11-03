import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:our_nest/features/chat/domain/chat_message_model.dart';
import 'package:our_nest/features/chat/domain/message_payload.dart';

void main() {
  group('Chat & E2EE - Payload & Message Models', () {
    test('MessagePayload correctly packages and unpacks text and replies', () {
      const payload = MessagePayload(
        text: 'Amma, wake me up 8am',
        replyToId: 'msg-prev-123',
      );

      final jsonStr = payload.toEncodedJson();
      expect(jsonStr, contains('Amma, wake me up 8am'));
      expect(jsonStr, contains('msg-prev-123'));

      final unpacked = MessagePayload.fromDecryptedJson(jsonStr);
      expect(unpacked.text, equals('Amma, wake me up 8am'));
      expect(unpacked.replyToId, equals('msg-prev-123'));
    });

    test('ChatMessage handles tombstone and deleted state', () {
      final activeMsg = ChatMessage(
        id: 'msg-1',
        familyId: 'fam-1',
        senderId: 'usr-1',
        type: MessageType.text,
        audience: MessageAudience.all,
        plaintext: jsonEncode({'text': 'Hello family!'}),
        isMine: true,
        createdAt: DateTime.now(),
      );

      expect(activeMsg.isDeleted, isFalse);
      expect(activeMsg.displayText, equals('Hello family!'));

      final deletedMsg = ChatMessage(
        id: 'msg-2',
        familyId: 'fam-1',
        senderId: 'usr-1',
        type: MessageType.text,
        audience: MessageAudience.all,
        plaintext: 'tombstone',
        isMine: true,
        createdAt: DateTime.now(),
        deletedAt: DateTime.now(),
      );

      expect(deletedMsg.isDeleted, isTrue);
      expect(deletedMsg.displayText, equals('This message was deleted'));
    });

    test('Audience parsing conforms to all vs selected', () {
      expect(MessageAudience.fromString('all'), equals(MessageAudience.all));
      expect(MessageAudience.fromString('selected'), equals(MessageAudience.selected));
      expect(MessageAudience.fromString('other'), equals(MessageAudience.all));
    });

    test('MessageType conversions match database constraints', () {
      expect(MessageType.fromString('text').toDbString(), equals('text'));
      expect(MessageType.fromString('photo').toDbString(), equals('photo'));
      expect(MessageType.fromString('voice').toDbString(), equals('voice'));
      expect(MessageType.fromString('alarm').toDbString(), equals('alarm'));
      expect(MessageType.fromString('alarm_event').toDbString(), equals('alarm_event'));
    });
  });
}
