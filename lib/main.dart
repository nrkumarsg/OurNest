import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/network/supabase_client.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
  };

  try {
    // 1. Initialize Supabase Client (config from --dart-define, see env.dart)
    await SupabaseService.init();
  } catch (_) {}

  try {
    // 2. Local notifications (alarm taps, message alerts) and push (F04/F06)
    await LocalNotifications.ensureInitialized();
    await PushService.configureBackgroundHandling();
  } catch (e) {
    debugPrint('Notification setup failed: $e');
  }

  // 3. Launch App inside Riverpod ProviderScope
  runApp(
    const ProviderScope(
      child: OurNestApp(),
    ),
  );
}
