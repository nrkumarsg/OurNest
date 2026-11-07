import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/notifications/notification_service.dart';
import 'core/platform/alarm_scheduler_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/share/share_intake.dart';

/// Opens the right screen for a tapped notification payload.
class NotificationRouting {
  NotificationRouting._();

  static void open(GoRouter router, String payload) {
    final alarmTap = AlarmSchedulerService.parsePayload(payload);
    if (alarmTap != null) {
      router.push('/alarm', extra: alarmTap);
    } else if (payload.startsWith('chat:')) {
      router.push('/chat/family');
    }
  }
}

class OurNestApp extends ConsumerStatefulWidget {
  const OurNestApp({super.key});

  @override
  ConsumerState<OurNestApp> createState() => _OurNestAppState();
}

class _OurNestAppState extends ConsumerState<OurNestApp> {
  StreamSubscription<String>? _tapSub;
  StreamSubscription<dynamic>? _shareSub;

  @override
  void initState() {
    super.initState();
    // Taps while the app is running. Cold-start taps are handled by the
    // splash screen once it knows the user is signed in.
    _tapSub = LocalNotifications.taps.listen((payload) {
      NotificationRouting.open(ref.read(appRouterProvider), payload);
    });
    ref.read(alarmSchedulerServiceProvider).onForegroundAlarmRing = (tap) {
      ref.read(appRouterProvider).push('/alarm', extra: tap);
    };
    // Text, links or photos shared from other apps open the family chat
    // (F44). The sign-in guard sends signed-out users to login first; the
    // share waits in pendingShareProvider until they reach home.
    _shareSub = ShareIntake.start(ref, onShare: (_) {
      ref.read(appRouterProvider).push('/chat/family');
    });
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final largeTextMode = ref.watch(largeTextModeProvider);

    return MaterialApp.router(
      title: 'OurNest',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(largeTextMode: largeTextMode),
      darkTheme: AppTheme.darkTheme(largeTextMode: largeTextMode),
      routerConfig: router,
    );
  }
}
