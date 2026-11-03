import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/nest_logo.dart';
import 'family_controller.dart';

class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Automatically check every 4 seconds so as soon as Admin approves,
    // the device enters the family chat automatically like WhatsApp Linked Devices!
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        ref.invalidate(currentMembershipProvider);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus(BuildContext context) async {
    ref.invalidate(currentMembershipProvider);
    final membership = await ref.read(currentMembershipProvider.future);

    if (!context.mounted) return;

    if (membership == null) {
      context.go('/family-entry');
    } else if (membership.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have been approved! Welcome to the family.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your request is still pending admin approval.'),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  Future<void> _cancelRequest(BuildContext context, String familyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: const Text(
            'Are you sure you want to cancel your request to join this family?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success =
          await ref.read(familyControllerProvider.notifier).leaveFamily(familyId);
      if (success && context.mounted) {
        context.go('/family-entry');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membershipAsync = ref.watch(currentMembershipProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Approval'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: membershipAsync.when(
            data: (membership) {
              if (membership == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) context.go('/family-entry');
                });
                return const SizedBox.shrink();
              }

              if (membership.isActive) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Approved by Admin! Welcome to your family circle.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    context.go('/home');
                  }
                });
                return const SizedBox.shrink();
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 1),
                  const Center(child: NestLogoMark(size: 90)),
                  const SizedBox(height: 24),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accentCoral.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'STATUS: WAITING FOR ADMIN APPROVAL',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentCoralDark,
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Ask Family Admin to Tap Approve (✓)',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You requested to join as ${membership.formattedRelation}.\nOpen the Family Circle screen on the Admin\'s phone and tap the green checkmark (✓). This screen will unlock automatically!',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(flex: 2),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Check Approval Status Now'),
                    onPressed: () => _checkStatus(context),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => _cancelRequest(context, membership.familyId),
                    child: const Text('Cancel Request'),
                  ),
                  const Spacer(flex: 1),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ),
    );
  }
}
