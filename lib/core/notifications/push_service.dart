import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/chat/data/chat_repository.dart';
import '../constants/env.dart';
import '../crypto/device_key_manager.dart';
import '../network/supabase_client.dart';
import '../platform/alarm_scheduler_service.dart';
import 'notification_service.dart';

/// Firebase settings come from `--dart-define` at build time, so no
/// google-services.json / GoogleService-Info.plist is committed. When they are
/// missing, push is simply switched off and the rest of the app still works.
///
///   flutter build apk \
///     --dart-define=FIREBASE_API_KEY=... \
///     --dart-define=FIREBASE_PROJECT_ID=... \
///     --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///     --dart-define=FIREBASE_ANDROID_APP_ID=... \
///     --dart-define=FIREBASE_IOS_APP_ID=...
class FirebaseConfig {
  FirebaseConfig._();

  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const iosBundleId =
      String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: 'com.ournest.app');

  /// Push runs on the native Android / iOS apps only (not web / desktop).
  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static FirebaseOptions? get options {
    if (!platformSupported ||
        apiKey.isEmpty ||
        projectId.isEmpty ||
        senderId.isEmpty) {
      return null;
    }
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final appId = isIos ? iosAppId : androidAppId;
    if (appId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      iosBundleId: isIos ? iosBundleId : null,
    );
  }

  static bool get isConfigured => options != null;
}

Future<bool> _ensureFirebase() async {
  final opts = FirebaseConfig.options;
  if (opts == null) return false;
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: opts);
  }
  return true;
}

/// Notification text for a push. Privacy: never message content, only who sent
/// it and what kind of thing it is.
@visibleForTesting
({String title, String body}) pushNotificationText(Map<String, dynamic> data) {
  final sender = (data['sender_name'] as String?)?.trim();
  final title = (sender == null || sender.isEmpty) ? 'OurNest' : sender;
  switch (data['message_type']) {
    case 'alarm':
      return (title: title, body: '⏰ Set a shared alarm');
    case 'alarm_event':
      return (title: title, body: '⏰ Alarm update');
    case 'photo':
      return (title: title, body: '📷 Sent a photo');
    case 'voice':
      return (title: title, body: '🎤 Sent a voice note');
    default:
      return (title: title, body: 'New message');
  }
}

Future<void> _showPushNotification(RemoteMessage message) async {
  final data = message.data;
  final familyId = data['family_id'] as String?;
  final text = pushNotificationText(data);
  await NotificationService.showMessageNotification(
    id: AlarmSchedulerService.stableId('msg:${data['message_id'] ?? message.messageId}'),
    title: text.title,
    body: text.body,
    payload: familyId != null ? NotificationService.chatPayload(familyId) : null,
  );
}

/// Runs in a separate background isolate when a push arrives while the app is
/// in the background or closed. It catches up the chat (which also schedules
/// shared-alarm escalations, F05) and shows a privacy-safe notification.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  if (!await _ensureFirebase()) return;

  final familyId = message.data['family_id'] as String?;
  final container = ProviderContainer();
  try {
    await Env.init();
    await SupabaseService.init();
    final signedIn = Supabase.instance.client.auth.currentUser != null;
    if (signedIn && familyId != null) {
      await container
          .read(chatRepositoryProvider)
          .syncMissedMessages(familyId)
          .timeout(const Duration(seconds: 20));
    }
  } catch (e) {
    debugPrint('Background push sync failed: $e');
  } finally {
    container.dispose();
  }

  try {
    // On iOS the push already carries a generic alert shown by the system;
    // showing our own as well would duplicate it.
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      await _showPushNotification(message);
    }
  } catch (e) {
    debugPrint('Could not show push notification: $e');
  }
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));

/// Registers this device for push once the user reaches the home screen.
final pushRegistrationProvider = FutureProvider<void>((ref) async {
  await ref.read(pushServiceProvider).registerCurrentDevice();
});

class PushService {
  final Ref _ref;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  PushService(this._ref);

  /// Call once from main() before runApp.
  static Future<void> configureBackgroundHandling() async {
    if (!FirebaseConfig.isConfigured) {
      debugPrint('Push disabled: FIREBASE_* dart-defines not set.');
      return;
    }
    try {
      await _ensureFirebase();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);
    } catch (e) {
      debugPrint('Firebase init failed, push disabled: $e');
    }
  }

  /// Asks for notification permission and saves this device's FCM token in
  /// `user_devices.fcm_token` so the push-dispatcher function can reach it.
  Future<void> registerCurrentDevice() async {
    if (_ref.read(supabaseClientProvider).auth.currentUser == null) return;
    try {
      await LocalNotifications.ensureInitialized(requestPermission: true);
      if (!await _ensureFirebase()) return;

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final keyManager = _ref.read(deviceKeyManagerProvider);
      await keyManager.ensureDeviceKeys();
      final deviceId = keyManager.currentDeviceId;
      if (deviceId == null) return;

      final token = await messaging.getToken();
      if (token != null) await _saveToken(deviceId, token);

      _tokenSub ??= messaging.onTokenRefresh.listen((t) {
        final id = _ref.read(deviceKeyManagerProvider).currentDeviceId;
        if (id != null) unawaited(_saveToken(id, t));
      });

      _foregroundSub ??= FirebaseMessaging.onMessage.listen((message) async {
        final familyId = message.data['family_id'] as String?;
        if (familyId != null) {
          try {
            await _ref.read(chatRepositoryProvider).syncMissedMessages(familyId);
          } catch (_) {}
        }
        // The app is open, so the chat already shows new messages. Only
        // alarms get a heads-up so they're never missed.
        if (message.data['message_type'] == 'alarm') {
          await _showPushNotification(message);
        }
      });
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  Future<void> _saveToken(String deviceId, String token) async {
    try {
      await _ref
          .read(notificationServiceProvider)
          .updateDeviceFcmToken(deviceId: deviceId, fcmToken: token);
    } catch (e) {
      debugPrint('Could not save FCM token: $e');
    }
  }

  /// On sign-out: stop pushes to this device for the old account.
  Future<void> unregisterCurrentDevice() async {
    await _tokenSub?.cancel();
    await _foregroundSub?.cancel();
    _tokenSub = null;
    _foregroundSub = null;
    final deviceId = _ref.read(deviceKeyManagerProvider).currentDeviceId;
    try {
      if (deviceId != null) {
        await _ref
            .read(notificationServiceProvider)
            .updateDeviceFcmToken(deviceId: deviceId, fcmToken: null);
      }
      if (FirebaseConfig.isConfigured && Firebase.apps.isNotEmpty) {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (e) {
      debugPrint('Push unregister failed: $e');
    }
  }
}
