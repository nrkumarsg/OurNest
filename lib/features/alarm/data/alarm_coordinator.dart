import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/platform/alarm_scheduler_service.dart';
import '../../chat/domain/message_payload.dart';
import '../domain/alarm_event_payload.dart';
import '../domain/shared_alarm_model.dart';

/// What a received message means for alarms on this device.
sealed class AlarmAction {
  const AlarmAction();
}

class ScheduleAlarmAction extends AlarmAction {
  final SharedAlarm alarm;
  const ScheduleAlarmAction(this.alarm);
}

class CancelAlarmAction extends AlarmAction {
  final String alarmId;
  const CancelAlarmAction(this.alarmId);
}

class NoAlarmAction extends AlarmAction {
  const NoAlarmAction();
}

final alarmCoordinatorProvider = Provider<AlarmCoordinator>((ref) {
  return AlarmCoordinator(
    ref.watch(alarmSchedulerServiceProvider),
    () => ref.read(supabaseClientProvider).auth.currentUser?.id,
  );
});

/// Makes shared alarms work across devices (audit F05):
/// * an `alarm` message schedules the escalation on participants' phones
///   (and the primary alarm on the owner's other devices);
/// * an `alarm_event` ack/cancel cancels it everywhere.
///
/// Called for every message stored by the chat sync – live (Realtime), on
/// catch-up, and from the background push handler.
class AlarmCoordinator {
  final AlarmSchedulerService _scheduler;
  final String? Function() _currentUserId;

  AlarmCoordinator(this._scheduler, this._currentUserId);

  /// Pure decision logic, kept separate so it can be unit-tested.
  static AlarmAction decide({
    required String messageType,
    required String plaintext,
  }) {
    final meta = MessagePayload.fromDecryptedJson(plaintext).alarmMeta;
    if (meta == null) return const NoAlarmAction();

    try {
      if (messageType == 'alarm') {
        if (meta['reminder_id'] != null) return const NoAlarmAction();
        final alarm = SharedAlarm.fromJson(meta);
        if (alarm.status == AlarmStatus.acknowledged ||
            alarm.status == AlarmStatus.cancelled) {
          return CancelAlarmAction(alarm.alarmId);
        }
        return ScheduleAlarmAction(alarm);
      }

      if (messageType == 'alarm_event') {
        final event = AlarmEventPayload.fromJson(meta);
        if (event.eventType == AlarmEventType.ack ||
            event.eventType == AlarmEventType.cancel) {
          return CancelAlarmAction(event.alarmId);
        }
      }
    } catch (e) {
      debugPrint('Ignoring malformed alarm payload: $e');
    }
    return const NoAlarmAction();
  }

  Future<void> onMessageStored({
    required String messageType,
    required String plaintext,
  }) async {
    final uid = _currentUserId();
    if (uid == null) return;

    final action = decide(messageType: messageType, plaintext: plaintext);
    switch (action) {
      case ScheduleAlarmAction(:final alarm):
        await _scheduler.scheduleAlarm(alarm: alarm, currentUserId: uid);
      case CancelAlarmAction(:final alarmId):
        await _scheduler.cancelAlarm(alarmId);
      case NoAlarmAction():
        break;
    }
  }
}
