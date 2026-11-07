import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/supabase_client.dart';

/// Single place that initialises flutter_local_notifications (audit F06).
///
/// Before, `initialize()` was never called, so scheduled alarms had no tap
/// handler and could fail to show. Both the alarm scheduler and message
/// notifications now go through [ensureInitialized].
class LocalNotifications {
  LocalNotifications._();

  static const messageChannelId = 'ournest_family_alerts_v2';
  static const messageChannelName = 'OurNest Messages & Badges';

  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;
  static String? _launchPayload;
  static final StreamController<String> _taps =
      StreamController<String>.broadcast();

  /// Payloads of notifications the user tapped while the app was running.
  static Stream<String> get taps => _taps.stream;

  /// Supported on Android, iOS and macOS only (not web / Windows / Linux).
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static Future<void> ensureInitialized({bool requestPermission = false}) async {
    if (!isSupported) return;
    if (!_ready) {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await plugin.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) _taps.add(payload);
        },
      );

      final launch = await plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _launchPayload = launch!.notificationResponse?.payload;
      }

      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              messageChannelId,
              messageChannelName,
              description: 'Family messages, unread icon badges and wake-up alerts',
              importance: Importance.max,
              enableVibration: true,
              playSound: true,
              showBadge: true,
            ),
          );
      _ready = true;
    }

    if (requestPermission) {
      // Android 13+ runtime permission, iOS alert permission.
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Payload of the notification that cold-started the app (read once).
  static String? takeLaunchPayload() {
    final p = _launchPayload;
    _launchPayload = null;
    return p;
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NotificationService(client);
});

class NotificationService {
  final SupabaseClient _client;
  static const MethodChannel _badgeChannel =
      MethodChannel('com.ournest.app/alarm_buzzer');

  NotificationService(this._client);

  /// Payload used for message notifications; tapping opens the family chat.
  static String chatPayload(String familyId) => 'chat:$familyId';

  /// Registers or updates device's FCM token in Supabase user_devices
  Future<void> updateDeviceFcmToken({
    required String deviceId,
    required String? fcmToken,
  }) async {
    await _client.from('user_devices').update({
      'fcm_token': fcmToken,
    }).eq('id', deviceId);
  }

  /// Updates the Android home screen launcher unread badge count `(1)`, `(2)`, etc.
  static Future<void> updateLauncherBadge(int count) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _badgeChannel.invokeMethod('updateBadge', {'count': count});
      } catch (_) {}
    }
  }

  /// Shows a privacy-safe message notification (sender name only, never content)
  /// and sets the Android home-screen app icon badge count.
  static Future<void> showMessageNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    int badgeCount = 1,
  }) async {
    await updateLauncherBadge(badgeCount);
    if (!LocalNotifications.isSupported) return;
    await LocalNotifications.ensureInitialized(requestPermission: true);
    await LocalNotifications.plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          LocalNotifications.messageChannelId,
          LocalNotifications.messageChannelName,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          channelShowBadge: true,
          number: badgeCount,
          category: AndroidNotificationCategory.message,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          badgeNumber: badgeCount,
        ),
      ),
      payload: payload,
    );
  }
}
