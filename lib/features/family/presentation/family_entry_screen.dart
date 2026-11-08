import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/nest_logo.dart';
import 'widgets/family_qr_scanner_modal.dart';

/// Opening Entrance Screen presented to a user who is not in any family/group yet.
/// Lets the user immediately pick:
/// 1. "I Have a Family / Group" (Scan QR Code or Enter 6-Digit Invite Code)
/// 2. "I Don't Have a Family / Group Yet" (Create a New Family / Group as Admin)
class FamilyEntryScreen extends StatelessWidget {
  const FamilyEntryScreen({super.key});

  Future<void> _openDirectQrScanner(BuildContext context) async {
    final result = await Navigator.of(context).push<ParsedFamilyInvite>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const FamilyQrScannerModal(),
      ),
    );

    if (result != null && context.mounted) {
      final query = Uri(
        queryParameters: {
          'code': result.code,
          if (result.familyName != null) 'name': result.familyName!,
          if (result.adminCity != null) 'city': result.adminCity!,
          if (result.adminAddress != null) 'addr': result.adminAddress!,
        },
      ).query;
      context.push('/join-family?$query');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final subColor = isDark
        ? const Color(0xFFCFD8DC)
        : AppColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        title: const NestWordmark(fontSize: 28),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: NestLogoMark(size: 76)),
              const SizedBox(height: 14),
              Text(
                'Welcome to OurNest',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Choose one option below to get started in seconds:',
                style: GoogleFonts.nunito(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: subColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),

              // ===============================================================
              // CHOICE 1: I HAVE A FAMILY / GROUP (SCAN QR OR ENTER 6-DIGIT CODE)
              // ===============================================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(isDark ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.primaryTeal,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTeal,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'OPTION 1 • JOIN EXISTING',
                                  style: GoogleFonts.nunito(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '📲 I Have a Family / Group',
                                style: GoogleFonts.nunito(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your Admin already created the Family, Tour, or Community Group. Scan their QR code or enter the 6-digit invite code — Family City & Home Address are copied automatically!',
                      style: GoogleFonts.nunito(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: subColor,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                      label: Text(
                        'Scan Family / Group QR Code',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      onPressed: () => _openDirectQrScanner(context),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryTeal,
                        side: const BorderSide(
                            color: AppColors.primaryTeal, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.vpn_key_rounded, size: 20),
                      label: Text(
                        'Enter 6-Digit Invite Code',
                        style: GoogleFonts.nunito(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: () => context.push('/join-family'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ===============================================================
              // CHOICE 2: I DON'T HAVE A FAMILY / GROUP YET (CREATE AS ADMIN)
              // ===============================================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.accentCoral.withOpacity(isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.accentCoral,
                    width: 1.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.accentCoral,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.add_home_work_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentCoralDark,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'OPTION 2 • START NEW AS ADMIN',
                                  style: GoogleFonts.nunito(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '🏠 I Don\'t Have a Family / Group Yet',
                                style: GoogleFonts.nunito(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Start a brand-new Family Circle, ✈️ Tour Group, 🛕 Temple / ⛪ Church Group, or ✨ Custom Group as Admin and get your QR code & 6-digit invite code to share.',
                      style: GoogleFonts.nunito(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: subColor,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCoral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.home_rounded, size: 22),
                      label: Text(
                        'Create New Family / Group (Admin)',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      onPressed: () => context.push('/create-family'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
