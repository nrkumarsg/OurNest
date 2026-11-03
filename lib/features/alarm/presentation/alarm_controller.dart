import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/platform/alarm_scheduler_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/domain/chat_message_model.dart';
import '../domain/alarm_event_payload.dart';
import '../domain/shared_alarm_model.dart';

final alarmControllerProvider =
    StateNotifierProvider<AlarmController, AsyncValue<void>>((ref) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  final scheduler = ref.watch(alarmSchedulerServiceProvider);
  return AlarmController(ref, chatRepo, scheduler);
});

class AlarmController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final ChatRepository _chatRepo;
  final AlarmSchedulerService _scheduler;

  AlarmController(this._ref, this._chatRepo, this._scheduler)
      : super(const AsyncValue.data(null));

  Future<bool> createAlarm({
    required String familyId,
    required DateTime time,
    required String label,
    required String ownerId,
    required String ownerName,
    required List<String> participants,
    int escalateAfterMin = 5,
  }) async {
    state = const AsyncValue.loading();
    try {
      final alarmId = DateTime.now().millisecondsSinceEpoch.toString();
      final alarm = SharedAlarm(
        alarmId: alarmId,
        time: time,
        label: label,
        ownerId: ownerId,
        ownerName: ownerName,
        participants: participants,
        escalateAfterMin: escalateAfterMin,
      );

      // 1. Send E2EE message with type = 'alarm'
      await _chatRepo.sendEncryptedMessage(
        familyId: familyId,
        text: '⏰ Shared Alarm: $label at ${alarm.formattedTime}',
        audience: MessageAudience.all,
        type: MessageType.alarm,
        alarmMeta: alarm.toJson(),
      );

      // 2. Schedule on local device
      final currentUid = _ref.read(authControllerProvider).user?.id ?? '';
      await _scheduler.scheduleAlarm(
        alarm: alarm,
        currentUserId: currentUid,
      );

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Owner taps "I'm awake": broadcasts ack event and cancels escalation alarms
  Future<void> acknowledgeAlarm({
    required String familyId,
    required String alarmId,
  }) async {
    final currentUid = _ref.read(authControllerProvider).user?.id ?? '';
    final event = AlarmEventPayload(
      alarmId: alarmId,
      eventType: AlarmEventType.ack,
      senderId: currentUid,
      timestamp: DateTime.now(),
    );

    // Broadcast E2EE alarm_event
    await _chatRepo.sendEncryptedMessage(
      familyId: familyId,
      text: '✓ I am awake!',
      audience: MessageAudience.all,
      type: MessageType.alarmEvent,
      alarmMeta: event.toJson(),
    );

    // Cancel local alarms
    await _scheduler.cancelAlarm(alarmId);
  }

  /// Cancels the alarm for everyone
  Future<void> cancelAlarm(String alarmId) async {
    await _scheduler.cancelAlarm(alarmId);
  }
}
