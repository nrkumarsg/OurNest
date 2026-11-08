import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/nest_logo.dart';
import '../../family/data/family_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/auth_state.dart';
import 'auth_controller.dart';

class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isNavigating = false;

  @override
  void dispose() {
    _emailController.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();

    final success =
        await ref.read(authControllerProvider.notifier).sendOtp(email);

    if (!mounted) return;

    if (success) {
      final latestAuth = ref.read(authControllerProvider);
      if (latestAuth.status == AuthStatus.authenticated &&
          latestAuth.user != null) {
        await _routeAfterAuthenticated();
      } else {
        context.push('/otp-verify');
      }
    } else {
      final error = ref.read(authControllerProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              error ?? 'Failed to sign in or send verification email. Please check the address.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated && next.user != null) {
        _routeAfterAuthenticated();
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Center(child: NestLogoMark(size: 80)),
                const SizedBox(height: 16),
                const Center(child: NestWordmark(fontSize: 32)),
                const SizedBox(height: 28),
                Text(
                  'Enter your email address',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your email address. We will send you a one-time verification code (6 to 8 digits).',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'name@example.com',
                    prefixIcon: Icon(
                      Icons.email_rounded,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email address';
                    }
                    final emailRegex =
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.mark_email_read_rounded),
                  label: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Send Sign-In Code'),
                  onPressed: isLoading ? null : _submit,
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'v1.2.3 • Email code sign-in • Closed family circle only',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
