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

  /// Owner taps "I'm awake": stops the alarm here and broadcasts an ack so
  /// every participant's escalation alarm is cancelled. Returns false if the
  /// family could not be told (e.g. offline).
  Future<bool> acknowledgeAlarm({
    required String familyId,
    required String alarmId,
  }) async {
    // Stop ringing locally first, even if the network is down.
    await _scheduler.cancelAlarm(alarmId);

    final currentUid = _ref.read(authControllerProvider).user?.id ?? '';
    final event = AlarmEventPayload(
      alarmId: alarmId,
      eventType: AlarmEventType.ack,
      senderId: currentUid,
      timestamp: DateTime.now(),
    );

    try {
      await _chatRepo.sendEncryptedMessage(
        familyId: familyId,
        text: '✓ I am awake!',
        audience: MessageAudience.all,
        type: MessageType.alarmEvent,
        alarmMeta: event.toJson(),
      );
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Cancels the alarm. The owner's cancel is broadcast so every participant's
  /// escalation is cancelled too; anyone else only silences it on this phone.
  Future<bool> cancelAlarm({
    required String familyId,
    required SharedAlarm alarm,
  }) async {
    await _scheduler.cancelAlarm(alarm.alarmId);

    final currentUid = _ref.read(authControllerProvider).user?.id ?? '';
    if (!alarm.isOwner(currentUid)) return true;

    try {
      final event = AlarmEventPayload(
        alarmId: alarm.alarmId,
        eventType: AlarmEventType.cancel,
        senderId: currentUid,
        timestamp: DateTime.now(),
      );
      await _chatRepo.sendEncryptedMessage(
        familyId: familyId,
        text: '🔕 Alarm cancelled: ${alarm.label}',
        audience: MessageAudience.all,
        type: MessageType.alarmEvent,
        alarmMeta: event.toJson(),
      );
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
