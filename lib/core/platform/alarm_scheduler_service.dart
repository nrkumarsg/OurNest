import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../features/alarm/domain/shared_alarm_model.dart';

final alarmSchedulerServiceProvider = Provider<AlarmSchedulerService>((ref) {
  return AlarmSchedulerService();
});

class AlarmSchedulerService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _alarmChannelId = 'ournest_exact_alarms_v1';
  static const String _alarmChannelName = 'OurNest Exact Alarms';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    tz.initializeTimeZones();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          _alarmChannelId,
          _alarmChannelName,
          description: 'Full-screen shared family alarms and wake-up escalation',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );

      // Request exact alarm permission on Android 12+ (API 31+)
      await androidImplementation?.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  /// Schedules a real exact local alarm for the owner and an escalation alarm for participants
  Future<void> scheduleAlarm({
    required SharedAlarm alarm,
    required String currentUserId,
  }) async {
    if (kIsWeb) return;
    await init();

    final isOwner = alarm.isOwner(currentUserId);
    final isParticipant = alarm.isParticipant(currentUserId);

    final alarmHashId = alarm.alarmId.hashCode;

    // 1. If current device belongs to the owner, schedule primary alarm at exact time
    if (isOwner) {
      if (alarm.time.isAfter(DateTime.now())) {
        final scheduledTz = tz.TZDateTime.from(alarm.time, tz.local);

        await _notifications.zonedSchedule(
          alarmHashId,
          '⏰ Wake-up Alarm: ${alarm.label}',
          'Time to wake up! Tap "I\'m awake" to confirm.',
          scheduledTz,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _alarmChannelId,
              _alarmChannelName,
              importance: Importance.max,
              priority: Priority.max,
              fullScreenIntent: true,
              ongoing: true,
              autoCancel: false,
              category: AndroidNotificationCategory.alarm,
              audioAttributesUsage: AudioAttributesUsage.alarm,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'alarm_ring:${alarm.alarmId}',
        );
      }
    }

    // 2. If current device is another participant (e.g. Amma/Dad), schedule the ESCALATION alarm
    // Rings at time + escalateAfterMin UNLESS the owner sends an ack!
    if (!isOwner && isParticipant) {
      final escalationTime = alarm.escalationTime;
      if (escalationTime.isAfter(DateTime.now())) {
        final escalationHashId = (alarm.alarmId + '_escalation').hashCode;
        final escalationTz = tz.TZDateTime.from(escalationTime, tz.local);

        await _notifications.zonedSchedule(
          escalationHashId,
          '🚨 Escalation: ${alarm.ownerName ?? "Family Member"} hasn\'t woken up!',
          'Tap to call them now.',
          escalationTz,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _alarmChannelId,
              _alarmChannelName,
              importance: Importance.max,
              priority: Priority.max,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
              audioAttributesUsage: AudioAttributesUsage.alarm,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              interruptionLevel: InterruptionLevel.critical,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'alarm_escalate:${alarm.alarmId}',
        );
      }
    }
  }

  /// Cancels both primary and escalation local alarms when acknowledged or cancelled
  Future<void> cancelAlarm(String alarmId) async {
    if (kIsWeb) return;
    await init();
    final alarmHashId = alarmId.hashCode;
    final escalationHashId = (alarmId + '_escalation').hashCode;

    await _notifications.cancel(alarmHashId);
    await _notifications.cancel(escalationHashId);
  }
}
