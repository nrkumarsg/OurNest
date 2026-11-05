import 'package:flutter/material.dart';
import '../../../app.dart' show NotificationRouting;
import '../../../core/notifications/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/nest_logo.dart';
import '../presentation/auth_controller.dart';
import '../../family/data/family_repository.dart';
import '../../profile/data/profile_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    // Brief splash delay for logo brand impression
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    try {
      final authState = ref.read(authControllerProvider);
      if (authState.user != null) {
        final profile = await ref
            .read(profileRepositoryProvider)
            .getProfile(authState.user!.id)
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        if (!mounted) return;
        if (profile == null || profile.displayName.isEmpty) {
          context.go('/profile-setup');
          return;
        }

        // Check family membership
        final membership = await ref
            .read(familyRepositoryProvider)
            .getCurrentUserMembership()
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        if (!mounted) return;

        if (membership == null) {
          context.go('/family-entry');
        } else if (membership.isPending) {
          context.go('/pending-approval');
        } else {
          context.go('/home');
          // App was opened by tapping a notification (e.g. a ringing alarm).
          final launchPayload = LocalNotifications.takeLaunchPayload();
          if (launchPayload != null) {
            NotificationRouting.open(GoRouter.of(context), launchPayload);
          }
        }
      } else {
        context.go('/phone-login');
      }
    } catch (_) {
      if (mounted) {
        final authState = ref.read(authControllerProvider);
        if (authState.user != null) {
          context.go('/profile-setup');
        } else {
          context.go('/phone-login');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                const NestLogoMark(size: 110),
                const SizedBox(height: 24),
                const NestWordmark(fontSize: 42),
                const SizedBox(height: 12),
                Text(
                  'Where your family talks.',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 2),
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryTeal),
                ),
                const SizedBox(height: 24),
                Text(
                  'Private • End-to-End Encrypted',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondaryLight.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
