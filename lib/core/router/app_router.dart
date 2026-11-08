import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/alarm/presentation/alarm_ringing_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
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
import 'route_guard.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever the user signs in or out (F26).
  final authChanges = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (prev, next) {
    if (prev?.user?.id != next.user?.id) authChanges.value++;
  });
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authChanges,
    redirect: (context, state) => RouteGuard.redirect(
      state.uri,
      loggedIn: ref.read(authControllerProvider).user != null,
    ),
    errorBuilder: (context, state) => const _NotFoundScreen(),
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
          final city = state.uri.queryParameters['city'];
          final addr = state.uri.queryParameters['addr'];
          return JoinFamilyScreen(
            initialCode: code,
            initialFamilyName: name,
            initialAdminCity: city,
            initialAdminAddress: addr,
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

/// Friendly page for unknown links instead of GoRouter's red error screen.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.travel_explore_rounded, size: 56),
                const SizedBox(height: 16),
                Text('This page could not be found',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('The link may be old or incomplete.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go to OurNest home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
