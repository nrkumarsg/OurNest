import 'message_payload.dart';

enum MessageAudience {
  all,
  selected;

  static MessageAudience fromString(String val) =>
      val == 'selected' ? MessageAudience.selected : MessageAudience.all;
}

enum MessageType {
  text,
  photo,
  voice,
  alarm,
  alarmEvent;

  static MessageType fromString(String val) {
    switch (val) {
      case 'photo':
        return MessageType.photo;
      case 'voice':
        return MessageType.voice;
      case 'alarm':
        return MessageType.alarm;
      case 'alarm_event':
        return MessageType.alarmEvent;
      default:
        return MessageType.text;
    }
  }

  String toDbString() {
    switch (this) {
      case MessageType.photo:
        return 'photo';
      case MessageType.voice:
        return 'voice';
      case MessageType.alarm:
        return 'alarm';
      case MessageType.alarmEvent:
        return 'alarm_event';
      default:
        return 'text';
    }
  }
}

class ChatMessage {
  final String id;
  final String familyId;
  final String senderId;
  final String? senderName;
  final MessageType type;
  final MessageAudience audience;
  final String plaintext;
  final String? replyToId;
  final List<String> recipientIds;
  final bool isMine;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  const ChatMessage({
    required this.id,
    required this.familyId,
    required this.senderId,
    this.senderName,
    required this.type,
    required this.audience,
    required this.plaintext,
    this.replyToId,
    this.recipientIds = const [],
    required this.isMine,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null && !isDeleted;

  MessagePayload get payload => MessagePayload.fromDecryptedJson(plaintext);
  String get displayText => isDeleted ? 'This message was deleted' : payload.text;
}
