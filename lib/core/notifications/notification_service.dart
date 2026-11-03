import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/supabase_client.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NotificationService(client);
});

class NotificationService {
  final SupabaseClient _client;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationService(this._client);

  static const String _channelId = 'ournest_family_alerts_v1';
  static const String _channelName = 'OurNest Messages & Alarms';

  Future<void> init() async {
    if (kIsWeb) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handled when user taps on notification
      },
    );

    // Create high-importance Android channel for immediate delivery
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'High priority family notifications and wake-up alerts',
          importance: Importance.max,
          enableVibration: true,
        ),
      );
    }
  }

  /// Registers or updates device's FCM token in Supabase user_devices
  Future<void> updateDeviceFcmToken({
    required String deviceId,
    required String fcmToken,
  }) async {
    await _client.from('user_devices').update({
      'fcm_token': fcmToken,
    }).eq('id', deviceId);
  }

  /// Displays local notification from a decrypted message or incoming FCM data message
  Future<void> showLocalMessageNotification({
    required int id,
    required String title,
    required String body,
    bool isAlarm = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'High priority alerts',
      importance: isAlarm ? Importance.max : Importance.high,
      priority: isAlarm ? Priority.max : Priority.high,
      fullScreenIntent: isAlarm,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }
}
