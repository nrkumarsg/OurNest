import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:our_nest/core/constants/app_colors.dart';
import 'package:our_nest/core/constants/app_typography.dart';
import 'package:our_nest/features/auth/domain/auth_state.dart';
import 'package:our_nest/features/family/domain/family_link_model.dart';
import 'package:our_nest/features/profile/domain/profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  group('Foundation - Branding & Theme Tokens', () {
    test('Primary and accent brand colors match OurNest specification', () {
      expect(AppColors.primaryTeal.value, equals(0xFF1F5C57));
      expect(AppColors.accentCoral.value, equals(0xFFE07A4F));
      expect(AppColors.backgroundLight.value, equals(0xFFF7F4EE));
      expect(AppColors.textPrimaryLight.value, equals(0xFF1E2B2A));
      expect(AppColors.textSecondaryLight.value, equals(0xFF4A5856));
    });

    test('Typography enforces elderly-friendly min 16sp body text', () {
      expect(AppTypography.minBodyFontSize, greaterThanOrEqualTo(16.0));
      expect(AppTypography.largeTextScale, greaterThan(1.0));
    });

    test('Touch target size adheres to minimum 48dp', () {
      expect(AppTypography.minTouchTargetSize, greaterThanOrEqualTo(48.0));
    });
  });

  group('Foundation - Domain Models', () {
    test('Profile serialization and deserialization works correctly', () {
      final now = DateTime.now();
      final profile = Profile(
        id: 'usr-1234',
        displayName: 'Amma',
        phone: '+1234567890',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: now,
      );

      final json = profile.toJson();
      expect(json['id'], equals('usr-1234'));
      expect(json['display_name'], equals('Amma'));
      expect(json['phone'], equals('+1234567890'));

      final reconstructed = Profile.fromJson({
        ...json,
        'created_at': now.toIso8601String(),
      });
      expect(reconstructed.id, equals(profile.id));
      expect(reconstructed.displayName, equals(profile.displayName));
      expect(reconstructed.phone, equals(profile.phone));
    });

    test('AuthState handles initial and loading states cleanly', () {
      final initial = AuthState.initial();
      expect(initial.status, equals(AuthStatus.initial));
      expect(initial.user, isNull);

      final withOtp = initial.copyWith(
        status: AuthStatus.otpSent,
        phoneNumber: '+1987654321',
      );
      expect(withOtp.status, equals(AuthStatus.otpSent));
      expect(withOtp.phoneNumber, equals('+1987654321'));
    });

    test('Rich Profile fields, birthday countdown, and fallback encoding round-trip', () {
      final now = DateTime.now();
      final dob = DateTime(1990, now.month, now.day);
      final richProfile = Profile(
        id: 'usr-rich-1',
        displayName: 'Karthik',
        phone: '+6591234567',
        sex: 'Male',
        dateOfBirth: dob,
        bloodGroup: 'O+',
        education: 'B.Tech Computer Science',
        occupation: 'Senior Architect',
        workingPlace: 'ARKIS PTE LTD',
        workingDetails: 'Cloud & Mobile Security Division, Singapore',
        livingPlace: 'Tampines, Singapore',
        statusText: 'At Work 💼',
        bioDescription: 'Loves family trips and weekend cooking.',
        createdAt: now,
      );

      expect(richProfile.isBirthdayToday, isTrue);
      expect(richProfile.daysUntilNextBirthday, equals(0));
      expect(richProfile.age, equals(now.year - 1990));

      final fallbackJson = richProfile.toFallbackCoreJson();
      final decoded = Profile.fromJson({
        ...fallbackJson,
        'created_at': now.toIso8601String(),
      });
      expect(decoded.sex, equals('Male'));
      expect(decoded.bloodGroup, equals('O+'));
      expect(decoded.education, equals('B.Tech Computer Science'));
      expect(decoded.occupation, equals('Senior Architect'));
      expect(decoded.workingPlace, equals('ARKIS PTE LTD'));
      expect(decoded.workingDetails, equals('Cloud & Mobile Security Division, Singapore'));
      expect(decoded.livingPlace, equals('Tampines, Singapore'));
      expect(decoded.statusText, equals('At Work 💼'));
      expect(decoded.bioDescription, equals('Loves family trips and weekend cooking.'));
    });

    test('FamilyLink model supports Family-to-Family Tree chain & policies', () {
      final link = FamilyLink(
        id: 'lnk-1',
        requesterFamilyId: 'fam-a',
        targetFamilyId: 'fam-b',
        connectedFamilyId: 'fam-b',
        connectedFamilyName: 'Ramesh Family',
        connectedInviteCode: 'RM2026',
        branchLabel: "Brother's Family",
        messagingPolicy: 'all_members',
        status: 'active',
        createdAt: DateTime.now(),
      );

      expect(link.isActive, isTrue);
      expect(link.adminsOnly, isFalse);
      expect(link.isNormalVisible, isTrue);
      final adminOnlyLink = link.copyWith(messagingPolicy: 'admins_only');
      expect(adminOnlyLink.adminsOnly, isTrue);

      final curtainHidden = link.copyWith(
        visibilityMode: 'curtain_hidden',
        hiddenScope: 'entire_family',
        hideOurUpdates: true,
      );
      expect(curtainHidden.isCurtainHidden, isTrue);
      expect(curtainHidden.hideOurUpdates, isTrue);
      expect(curtainHidden.peaceStatusLabel, contains('Curtain Mode'));
    });
  });
}
