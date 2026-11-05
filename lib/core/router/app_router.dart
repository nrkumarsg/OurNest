import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/alarm/presentation/alarm_ringing_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_input_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/home_chat_screen.dart';
import '../../features/family/presentation/create_family_screen.dart';
import '../../features/family/presentation/family_entry_screen.dart';
import '../../features/family/presentation/family_screen.dart';
import '../../features/family/presentation/join_family_screen.dart';
import '../../features/family/presentation/pending_approval_screen.dart';
import '../../features/help/presentation/help_guide_screen.dart';
import '../../features/profile/presentation/profile_setup_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../platform/alarm_scheduler_service.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/phone-login',
        builder: (context, state) => const PhoneInputScreen(),
      ),
      GoRoute(
        path: '/otp-verify',
        builder: (context, state) => const OtpScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) {
          final isEdit = state.uri.queryParameters['edit'] == 'true';
          return ProfileSetupScreen(isEditing: isEdit);
        },
      ),
      GoRoute(
        path: '/family-entry',
        builder: (context, state) => const FamilyEntryScreen(),
      ),
      GoRoute(
        path: '/create-family',
        builder: (context, state) => const CreateFamilyScreen(),
      ),
      GoRoute(
        path: '/join-family',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          final name = state.uri.queryParameters['name'];
          return JoinFamilyScreen(
            initialCode: code,
            initialFamilyName: name,
          );
        },
      ),
      GoRoute(
        path: '/pending-approval',
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeChatScreen(),
      ),
      GoRoute(
        path: '/family',
        builder: (context, state) => const FamilyScreen(),
      ),
      GoRoute(
        path: '/chat/:threadId',
        builder: (context, state) {
          final threadId = state.pathParameters['threadId'] ?? 'family';
          return ChatScreen(threadId: threadId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpGuideScreen(),
      ),
      // Opened by tapping an alarm / escalation notification (F05).
      GoRoute(
        path: '/alarm',
        builder: (context, state) {
          final tap = state.extra as AlarmNotificationTap?;
          if (tap == null) return const SplashScreen();
          return AlarmRingingScreen(
            alarm: tap.alarm,
            isEscalation: tap.isEscalation,
          );
        },
      ),
    ],
  );
});
