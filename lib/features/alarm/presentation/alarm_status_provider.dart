import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chat/domain/chat_message_model.dart';
import '../../chat/presentation/chat_controller.dart';
import '../domain/alarm_event_payload.dart';
import '../domain/shared_alarm_model.dart';

/// Latest status of each shared alarm, worked out from the "I'm awake" /
/// cancel events in the family chat. The alarm card used to show only the
/// status frozen in the original alarm message, so it stayed "active" forever.
final alarmStatusOverridesProvider =
    Provider.autoDispose<Map<String, AlarmStatus>>((ref) {
  final messages = ref.watch(familyMessagesProvider).value ?? const [];
  return alarmStatusFromMessages(messages);
});

Map<String, AlarmStatus> alarmStatusFromMessages(List<ChatMessage> messages) {
  final result = <String, AlarmStatus>{};
  // Messages are in time order, so later events win.
  for (final m in messages) {
    if (m.type != MessageType.alarmEvent || m.isDeleted) continue;
    final meta = m.payload.alarmMeta;
    if (meta == null) continue;
    try {
      final event = AlarmEventPayload.fromJson(meta);
      switch (event.eventType) {
        case AlarmEventType.ack:
          result[event.alarmId] = AlarmStatus.acknowledged;
        case AlarmEventType.cancel:
          result[event.alarmId] = AlarmStatus.cancelled;
        default:
          break;
      }
    } catch (_) {
      // Ignore malformed events.
    }
  }
  return result;
}
