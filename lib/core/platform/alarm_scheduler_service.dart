import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../features/alarm/domain/shared_alarm_model.dart';
import '../notifications/notification_service.dart';

final alarmSchedulerServiceProvider = Provider<AlarmSchedulerService>((ref) {
  return AlarmSchedulerService();
});

/// A parsed alarm notification payload (what the user tapped).
class AlarmNotificationTap {
  final SharedAlarm alarm;
  final bool isEscalation;
  const AlarmNotificationTap(this.alarm, {required this.isEscalation});
}

enum ReminderScheduleResult { scheduled, inPast, unsupported }

class AlarmSchedulerService {
  static const String _alarmChannelId = 'ournest_exact_alarms_v3';
  static const String _alarmChannelName = 'OurNest Loud Wake-Up Alarms';
  static const MethodChannel _buzzerChannel =
      MethodChannel('com.ournest.app/alarm_buzzer');
  static final Int64List _alarmVibrationPattern =
      Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1200]);
  static final Int32List _insistentNotificationFlag =
      Int32List.fromList([4]); // Notification.FLAG_INSISTENT = 4

  /// Payload prefixes. MainActivity.kt only allows lock-screen display for
  /// notifications whose payload starts with one of these.
  static const ringPrefix = 'alarm_ring:';
  static const escalatePrefix = 'alarm_escalate:';

  bool _initialized = false;
  Timer? _fallbackBuzzerTimer;
  final Map<String, Timer> _foregroundTimers = {};
  void Function(AlarmNotificationTap tap)? onForegroundAlarmRing;

  FlutterLocalNotificationsPlugin get _notifications => LocalNotifications.plugin;

  /// Starts the continuous hardware alarm ringtone + vibration on Android
  /// (plus system alert sound + haptics fallback on all platforms).
  Future<void> startBuzzer() async {
    stopBuzzer();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _buzzerChannel.invokeMethod('startBuzzer');
      } catch (_) {}
    }
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.vibrate();
    } catch (_) {}
    _fallbackBuzzerTimer =
        Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        await HapticFeedback.vibrate();
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    });
  }

  /// Stops the continuous hardware alarm ringtone + vibration.
  Future<void> stopBuzzer() async {
    _fallbackBuzzerTimer?.cancel();
    _fallbackBuzzerTimer = null;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _buzzerChannel.invokeMethod('stopBuzzer');
      } catch (_) {}
    }
  }

  /// Stable 31-bit notification id (FNV-1a). Dart's String.hashCode is not
  /// guaranteed to be the same across isolates/app runs, and the background
  /// push isolate must be able to cancel what the main isolate scheduled.
  static int stableId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(key)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  static int ringId(String alarmId) => stableId('ring:$alarmId');
  static int escalationId(String alarmId) => stableId('escalate:$alarmId');

  /// `alarm_ring:<id>|<base64url(alarm json)>` – carries the alarm so tapping
  /// the notification can open the ringing screen even after a cold start.
  static String buildPayload({required SharedAlarm alarm, required bool escalation}) {
    final data = base64Url.encode(utf8.encode(jsonEncode(alarm.toJson())));
    return '${escalation ? escalatePrefix : ringPrefix}${alarm.alarmId}|$data';
  }

  static AlarmNotificationTap? parsePayload(String? payload) {
    if (payload == null) return null;
    final bool escalation;
    if (payload.startsWith(ringPrefix)) {
      escalation = false;
    } else if (payload.startsWith(escalatePrefix)) {
      escalation = true;
    } else {
      return null;
    }
    final sep = payload.indexOf('|');
    if (sep < 0) return null;
    try {
      final json = jsonDecode(utf8.decode(base64Url.decode(payload.substring(sep + 1))));
      return AlarmNotificationTap(
        SharedAlarm.fromJson(Map<String, dynamic>.from(json as Map)),
        isEscalation: escalation,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    if (_initialized || !LocalNotifications.isSupported) return;
    tz.initializeTimeZones();
    await LocalNotifications.ensureInitialized();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.createNotificationChannel(
        AndroidNotificationChannel(
          _alarmChannelId,
          _alarmChannelName,
          description: 'Full-screen shared family alarms and wake-up escalation',
          importance: Importance.max,
          enableVibration: true,
          vibrationPattern: _alarmVibrationPattern,
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );

      // Android 12+ exact alarm permission (opens settings only if not granted).
      final canExact =
          await androidImplementation?.canScheduleExactNotifications() ?? true;
      if (!canExact) {
        await androidImplementation?.requestExactAlarmsPermission();
      }
    }

    _initialized = true;
  }

  void _scheduleForegroundBuzzerTimer({
    required SharedAlarm alarm,
    required bool isOwner,
  }) {
    _foregroundTimers[alarm.alarmId]?.cancel();
    final rawDelay = alarm.time.difference(DateTime.now());
    // If the alarm was set for more than 90 seconds in the past, ignore it
    if (rawDelay.inSeconds < -90) return;
    final effectiveDelay =
        rawDelay.isNegative ? const Duration(milliseconds: 300) : rawDelay;
    _foregroundTimers[alarm.alarmId] = Timer(effectiveDelay, () {
      startBuzzer();
      onForegroundAlarmRing?.call(
        AlarmNotificationTap(alarm, isEscalation: !isOwner),
      );
    });
  }

  /// Schedules the primary alarm on BOTH the owner's and participants' devices
  /// at `alarm.time`, plus the escalation follow-up on participants' devices.
  Future<void> scheduleAlarm({
    required SharedAlarm alarm,
    required String currentUserId,
  }) async {
    final isOwner = alarm.isOwner(currentUserId);
    final isParticipant = alarm.isParticipant(currentUserId);
    final now = DateTime.now();
    final isDueOrUpcoming =
        alarm.time.isAfter(now.subtract(const Duration(seconds: 90)));

    if ((isOwner || isParticipant) && isDueOrUpcoming) {
      _scheduleForegroundBuzzerTimer(alarm: alarm, isOwner: isOwner);
    }

    if (!LocalNotifications.isSupported) return;
    await init();

    // 1. Primary alarm at the exact time on BOTH phones (owner + all participants)
    if ((isOwner || isParticipant) && isDueOrUpcoming) {
      final scheduleTime = alarm.time.isAfter(now.add(const Duration(seconds: 2)))
          ? alarm.time
          : now.add(const Duration(seconds: 2));
      await _notifications.zonedSchedule(
        ringId(alarm.alarmId),
        isOwner
            ? '⏰ Wake-up Alarm: ${alarm.label}'
            : '⏰ Shared Family Alarm (${alarm.ownerName ?? "Family"}): ${alarm.label}',
        isOwner
            ? 'Time to wake up! Tap "I\'m awake" to confirm.'
            : 'Shared wake-up alarm is ringing! Tap to open or call.',
        tz.TZDateTime.from(scheduleTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _alarmChannelId,
            _alarmChannelName,
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            ongoing: true,
            autoCancel: false,
            playSound: true,
            enableVibration: true,
            vibrationPattern: _alarmVibrationPattern,
            additionalFlags: _insistentNotificationFlag,
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
        payload: buildPayload(alarm: alarm, escalation: !isOwner),
      );
    }

    // 2. Other participants: escalation follow-up at time + escalateAfterMin,
    //    cancelled when the owner's "I'm awake" (ack) event arrives.
    if (!isOwner &&
        isParticipant &&
        alarm.escalateAfterMin > 0 &&
        alarm.escalationTime.isAfter(now)) {
      await _notifications.zonedSchedule(
        escalationId(alarm.alarmId),
        '🚨 Escalation: ${alarm.ownerName ?? "Family Member"} hasn\'t woken up!',
        'Tap to call them now.',
        tz.TZDateTime.from(alarm.escalationTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _alarmChannelId,
            _alarmChannelName,
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            ongoing: true,
            autoCancel: false,
            playSound: true,
            enableVibration: true,
            vibrationPattern: _alarmVibrationPattern,
            additionalFlags: _insistentNotificationFlag,
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
        payload: buildPayload(alarm: alarm, escalation: true),
      );
    }
  }

  /// Real permission state for the settings screen (F35).
  /// Returns null where it can't be checked (web, desktop, iOS).
  Future<bool?> alarmPermissionsGranted() async {
    if (!LocalNotifications.isSupported ||
        defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    await LocalNotifications.ensureInitialized();
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notificationsOn = await android?.areNotificationsEnabled() ?? false;
    final exactOn = await android?.canScheduleExactNotifications() ?? false;
    return notificationsOn && exactOn;
  }

  /// Asks for notification + exact-alarm permission (opens system settings
  /// for the exact-alarm one when needed).
  Future<void> requestAlarmPermissions() async {
    if (!LocalNotifications.isSupported) return;
    await LocalNotifications.ensureInitialized(requestPermission: true);
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null && !(await android.canScheduleExactNotifications() ?? true)) {
      await android.requestExactAlarmsPermission();
    }
  }

  static int reminderId(String id) => stableId('reminder:$id');

  /// Schedules a one-off reminder notification on THIS phone (audit F09:
  /// the "Add to calendar" button used to only show a snackbar).
  Future<ReminderScheduleResult> scheduleReminder({
    required String reminderKey,
    required String title,
    required DateTime at,
    String? notes,
  }) async {
    if (!LocalNotifications.isSupported) return ReminderScheduleResult.unsupported;
    if (!at.isAfter(DateTime.now())) return ReminderScheduleResult.inPast;
    await init();
    await _notifications.zonedSchedule(
      reminderId(reminderKey),
      '📅 $title',
      (notes != null && notes.trim().isNotEmpty) ? notes.trim() : 'Family reminder',
      tz.TZDateTime.from(at, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          LocalNotifications.messageChannelId,
          LocalNotifications.messageChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    return ReminderScheduleResult.scheduled;
  }

  /// Cancels both primary and escalation alarms on this device and stops buzzer.
  Future<void> cancelAlarm(String alarmId) async {
    _foregroundTimers.remove(alarmId)?.cancel();
    await stopBuzzer();
    if (!LocalNotifications.isSupported) return;
    await init();
    await _notifications.cancel(ringId(alarmId));
    await _notifications.cancel(escalationId(alarmId));
  }
}
