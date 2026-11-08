import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../family/data/family_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/auth_state.dart';
import 'auth_controller.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  int _secondsRemaining = 45;
  Timer? _timer;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _routeAfterAuthenticated() async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    try {
      final user = ref.read(authControllerProvider).user;
      if (user == null) {
        _isNavigating = false;
        return;
      }

      final profile = await ref
          .read(profileRepositoryProvider)
          .getProfile(user.id)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      if (!mounted) return;

      if (profile == null || profile.displayName.isEmpty) {
        final existingMembership = await ref
            .read(familyRepositoryProvider)
            .getCurrentUserMembership()
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        if (!mounted) return;
        if (existingMembership == null) {
          context.go('/family-entry');
        } else {
          context.go('/profile-setup');
        }
        return;
      }

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
      }
    } catch (_) {
      if (mounted) {
        context.go('/family-entry');
      }
    }
  }

  Future<void> _verify([String? customInput]) async {
    final code = (customInput ?? _otpController.text).trim();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please enter the 6 to 8-digit verification code from your email.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success =
        await ref.read(authControllerProvider.notifier).verifyOtp(code);

    if (!mounted) return;

    if (success) {
      await _routeAfterAuthenticated();
    } else {
      final error = ref.read(authControllerProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Invalid or expired verification code. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pasteAndVerifyCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text?.trim() ?? '';
    if (pasted.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Clipboard is empty. Copy the verification code from your email first, then tap Paste!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    _otpController.text = pasted;
    await _verify(pasted);
  }

  Future<void> _resend() async {
    final sent = await ref.read(authControllerProvider.notifier).resendOtp();
    if (sent) {
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A fresh dynamic verification code has been emailed!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Also listen for deep-link magic link completion automatically
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated && next.user != null) {
        _routeAfterAuthenticated();
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final email = authState.email ?? 'your email';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email Code'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Icon(
                Icons.mark_email_unread_rounded,
                size: 56,
                color: AppColors.primaryTeal,
              ),
              const SizedBox(height: 16),
              Text(
                'Check your email inbox',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a dynamic verification code to:\n$email',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6 to 8-digit verification code from your email below.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Large legible 6-to-8 digit OTP input
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                autofocus: true,
                maxLength: 8,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4.0,
                  color: AppColors.primaryTeal,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Enter 6 or 8-digit code',
                  hintStyle: GoogleFonts.nunito(
                    fontSize: 16,
                    color: AppColors.textSecondaryLight.withOpacity(0.6),
                    letterSpacing: 0.5,
                  ),
                ),
                onChanged: (val) {
                  final trimmed = val.trim();
                  // Automatically verify when an 8-digit code is completed
                  // (6-digit codes can also be verified immediately via Verify & Continue)
                  if (trimmed.length == 8 && int.tryParse(trimmed) != null) {
                    _verify(trimmed);
                  }
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.content_paste_go_rounded,
                    color: AppColors.primaryTeal),
                label: Text(
                  '📋 Paste Verification Code from Email',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryTeal,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  side: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isLoading ? null : _pasteAndVerifyCode,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : () => _verify(),
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Verify & Continue'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_secondsRemaining > 0)
                    Text(
                      'Resend email in ${_secondsRemaining}s',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondaryLight,
                          ),
                    )
                  else
                    TextButton.icon(
                      onPressed: _resend,
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.accentCoral),
                      label: Text(
                        'Resend Email Code',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentCoral,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
