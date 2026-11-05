import 'dart:convert';

/// Structure of the decrypted JSON payload that travels inside the XChaCha20 ciphertext.
class MessagePayload {
  final String text;
  final String? replyToId;
  final Map<String, dynamic>? mediaMeta; // Used in Phase 4 for photos & voice notes
  final Map<String, dynamic>? alarmMeta; // Used in Phase 5 for alarms

  /// Who the sender addressed this message to (including the sender).
  ///
  /// Carried inside the encrypted payload so receivers can tell a 1-to-1
  /// message from a "selected members" group message (audit F22) without the
  /// server having to reveal the full recipient list. Null for messages sent
  /// by older app versions.
  final List<String>? recipientIds;

  const MessagePayload({
    required this.text,
    this.replyToId,
    this.mediaMeta,
    this.alarmMeta,
    this.recipientIds,
  });

  factory MessagePayload.fromJson(Map<String, dynamic> json) {
    final rawRecipients = json['recipients'];
    return MessagePayload(
      text: json['text'] as String? ?? '',
      replyToId: json['reply_to'] as String?,
      mediaMeta: json['media_meta'] as Map<String, dynamic>?,
      alarmMeta: json['alarm_meta'] as Map<String, dynamic>?,
      recipientIds: rawRecipients is List
          ? rawRecipients.map((e) => e.toString()).toList()
          : null,
    );
  }

  factory MessagePayload.fromDecryptedJson(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return MessagePayload.fromJson(map);
    } catch (_) {
      // In case raw string was stored
      return MessagePayload(text: jsonStr);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'reply_to': replyToId,
      if (mediaMeta != null) 'media_meta': mediaMeta,
      if (alarmMeta != null) 'alarm_meta': alarmMeta,
      if (recipientIds != null) 'recipients': recipientIds,
    };
  }

  String toEncodedJson() => jsonEncode(toJson());
}
