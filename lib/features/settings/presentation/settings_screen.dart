import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_version.dart';
import '../../../core/platform/alarm_scheduler_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/profile_controller.dart';

/// Real alarm/notification permission state (was always shown as "ready").
final alarmPermissionStatusProvider = FutureProvider.autoDispose<bool?>((ref) {
  return ref.read(alarmSchedulerServiceProvider).alarmPermissionsGranted();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Uint8List? _decodeAvatar(String? avatarUrl) {
    if (avatarUrl == null || !avatarUrl.startsWith('data:image')) return null;
    try {
      final commaIdx = avatarUrl.indexOf(',');
      if (commaIdx != -1) {
        return base64Decode(avatarUrl.substring(commaIdx + 1));
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final authState = ref.watch(authControllerProvider);
    final email = authState.user?.email ?? authState.email ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLargeText = ref.watch(largeTextModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // User Card
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push('/profile-setup?edit=true'),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Builder(builder: (context) {
                            final bytes = _decodeAvatar(profile?.avatarUrl);
                            return CircleAvatar(
                              radius: 32,
                              backgroundColor:
                                  AppColors.primaryTeal.withOpacity(0.12),
                              backgroundImage:
                                  bytes != null ? MemoryImage(bytes) : null,
                              child: bytes == null
                                  ? Text(
                                      profile?.displayName.isNotEmpty == true
                                          ? profile!.displayName[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.nunito(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryTeal,
                                      ),
                                    )
                                  : null,
                            );
                          }),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile?.displayName ?? 'Family Member',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                if (profile?.statusText != null &&
                                    profile!.statusText!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '"${profile.statusText!}"',
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryTeal,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                if (email.isNotEmpty)
                                  Text(
                                    email,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                if (profile?.livingPlace != null &&
                                    profile!.livingPlace!.isNotEmpty)
                                  Text(
                                    '📍 ${profile.livingPlace!}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                if (profile?.workingPlace != null &&
                                    profile!.workingPlace!.isNotEmpty)
                                  Text(
                                    '🏢 ${profile.occupation != null && profile.occupation!.isNotEmpty ? "${profile.occupation} @ " : ""}${profile.workingPlace!}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded,
                                color: AppColors.primaryTeal, size: 28),
                            tooltip: 'Edit Family Profile',
                            onPressed: () =>
                                context.push('/profile-setup?edit=true'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.badge_rounded, size: 18),
                          label: const Text(
                              'Edit Personal Profile (Photo, DOB, Work & Residence)'),
                          onPressed: () =>
                              context.push('/profile-setup?edit=true'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Accessibility & Display Section
            Text(
              'Accessibility & Appearance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondaryLight,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Large Text Mode'),
                    subtitle: const Text('Increases font size for comfortable reading'),
                    value: isLargeText,
                    activeColor: AppColors.primaryTeal,
                    onChanged: (val) {
                      ref.read(largeTextModeProvider.notifier).set(val);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Reduces eye strain in low-light settings'),
                    value: isDark,
                    activeColor: AppColors.primaryTeal,
                    onChanged: (val) {
                      ref.read(themeModeProvider.notifier).toggleTheme(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Privacy & Security Section
            Text(
              'Security & Encryption',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondaryLight,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.security_rounded, color: AppColors.primaryTeal),
                    title: const Text('End-to-End Encryption'),
                    subtitle: const Text('Active (X25519 & XChaCha20-Poly1305)'),
                    trailing: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                  ),
                  const Divider(height: 1),
                  Builder(builder: (context) {
                    final permission = ref.watch(alarmPermissionStatusProvider);
                    final granted = permission.value;
                    final subtitle = permission.isLoading
                        ? 'Checking…'
                        : granted == null
                            ? 'Alarms ring only in the Android / iPhone app'
                            : granted
                                ? 'Allowed – shared wake-up alarms can ring'
                                : 'Not allowed – tap to allow, or alarms may not ring';
                    return ListTile(
                      leading: const Icon(Icons.alarm_rounded, color: AppColors.accentCoral),
                      title: const Text('Alarm & Reminders Permission'),
                      subtitle: Text(subtitle),
                      trailing: granted == true
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                          : granted == false
                              ? const Icon(Icons.warning_amber_rounded, color: AppColors.error)
                              : null,
                      onTap: granted == false
                          ? () async {
                              await ref
                                  .read(alarmSchedulerServiceProvider)
                                  .requestAlarmPermissions();
                              ref.invalidate(alarmPermissionStatusProvider);
                            }
                          : null,
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Help & Information Section
            Text(
              'Help & Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondaryLight,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.menu_book_rounded, color: AppColors.primaryTeal),
                    title: const Text('Help & User Guide'),
                    subtitle: const Text('Full instructions for all app features and flows'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () => context.push('/help'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AppColors.accentCoral),
                    title: const Text('About OurNest'),
                    subtitle: const Text(
                        'v$appVersionLabel • Developed by ARKIS PTE LTD'),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'OurNest',
                        applicationVersion: appVersionLabel,
                        applicationLegalese:
                            '© 2026 OurNest. All rights reserved.\nDeveloped by ARKIS PTE LTD.',
                        children: const [
                          SizedBox(height: 12),
                          Text(
                            'OurNest is a private, family-only messenger with end-to-end encryption, audience controls, and shared wake-up alarms.',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Sign Out
            OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/phone-login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
