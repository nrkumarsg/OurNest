import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/network/supabase_client.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Audit F31: log every uncaught error instead of losing it silently.
  // (A crash-reporting service such as Sentry/Crashlytics can be plugged in
  // here later – that's a third-party choice for the owner.)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error\n$stack');
    return true; // handled: keep the app running
  };

  await _startApp();
}

Future<void> _startApp() async {
  // 1. Supabase client (config from --dart-define, see env.dart)
  final ready = await SupabaseService.init();
  if (!ready) {
    runApp(const StartupErrorApp(onRetry: _startApp));
    return;
  }

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

/// Shown when the app can't start its connection to the server, instead of
/// continuing and crashing on the first screen (F31).
class StartupErrorApp extends StatelessWidget {
  final Future<void> Function() onRetry;

  const StartupErrorApp({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    "OurNest can't connect right now",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please check your internet connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
