import 'dart:async';
import 'package:flutter/foundation.dart';
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

  static const messageChannelId = 'ournest_family_alerts_v1';
  static const messageChannelName = 'OurNest Messages & Alarms';

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
              description: 'Family messages and wake-up alerts',
              importance: Importance.high,
              enableVibration: true,
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

  /// Shows a privacy-safe message notification (sender name only, never content).
  static Future<void> showMessageNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!LocalNotifications.isSupported) return;
    await LocalNotifications.ensureInitialized();
    await LocalNotifications.plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          LocalNotifications.messageChannelId,
          LocalNotifications.messageChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}
