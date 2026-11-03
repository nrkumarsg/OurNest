import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/nest_logo.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/profile_controller.dart';

class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLargeText = ref.watch(largeTextModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const NestWordmark(fontSize: 26),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: 'Toggle Theme',
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme(!isDark);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/phone-login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Center(child: NestLogoMark(size: 80)),
              const SizedBox(height: 20),
              profileAsync.when(
                data: (profile) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.primaryTeal.withOpacity(0.15),
                          child: Text(
                            (profile?.displayName.isNotEmpty == true)
                                ? profile!.displayName[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.nunito(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Welcome, ${profile?.displayName ?? 'Family Member'}!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile?.phone ?? 'Phone authenticated',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondaryLight,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading profile: $e'),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phase 1: Foundation Complete ✓',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.primaryTeal,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Phone OTP Auth with Supabase\n'
                        '• User Profile & DB Migration\n'
                        '• OurNest Branding (#1F5C57 & #E07A4F)\n'
                        '• Elderly-friendly minimum 16sp & 48dp touch targets',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Large Text (Elderly-Friendly)'),
                        subtitle: const Text('Increases text size for easier reading'),
                        value: isLargeText,
                        activeColor: AppColors.primaryTeal,
                        onChanged: (val) {
                          ref.read(largeTextModeProvider.notifier).set(val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.group_add_rounded),
                label: const Text('Next: Phase 2 (Family Creation & Invites)'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Awaiting your review to start Phase 2!'),
                      backgroundColor: AppColors.primaryTeal,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
