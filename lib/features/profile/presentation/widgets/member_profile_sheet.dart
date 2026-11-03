import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../family/domain/family_member_model.dart';
import '../../domain/profile_model.dart';

class MemberProfileSheet extends StatelessWidget {
  final FamilyMember member;
  final bool isSelf;
  final String? familyBranchName;

  const MemberProfileSheet({
    super.key,
    required this.member,
    this.isSelf = false,
    this.familyBranchName,
  });

  Widget _buildAvatar(Profile? profile, String displayName) {
    final avatarUrl = profile?.avatarUrl;
    if (avatarUrl != null && avatarUrl.startsWith('data:image')) {
      try {
        final commaIdx = avatarUrl.indexOf(',');
        final bytes = base64Decode(avatarUrl.substring(commaIdx + 1));
        return CircleAvatar(
          radius: 46,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }

    return CircleAvatar(
      radius: 46,
      backgroundColor: AppColors.primaryTeal.withOpacity(0.15),
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: GoogleFonts.nunito(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          color: AppColors.primaryTeal,
        ),
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^\d+]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String whatsapp) async {
    final digits = whatsapp.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$digits');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openAddressInMaps(String address) async {
    final query = Uri.encodeComponent(address.trim());
    if (query.isEmpty) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final profile = member.profile;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final secondaryColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Avatar + Name + Relation + Status
            Center(child: _buildAvatar(profile, member.displayName)),
            const SizedBox(height: 12),
            Text(
              member.displayName,
              style: GoogleFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    member.formattedRelation,
                    style: GoogleFonts.nunito(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                ),
                if (member.isAdmin)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentCoral.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Family Admin',
                      style: GoogleFonts.nunito(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentCoralDark,
                      ),
                    ),
                  ),
                if (familyBranchName != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '🌳 $familyBranchName',
                      style: GoogleFonts.nunito(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.info,
                      ),
                    ),
                  ),
              ],
            ),

            if (profile?.statusText != null &&
                profile!.statusText!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '"${profile.statusText!}"',
                style: GoogleFonts.nunito(
                  fontSize: 14.5,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: secondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Upcoming Birthday Banner if DOB is set
            if (profile?.dateOfBirth != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: profile!.isBirthdayToday
                      ? AppColors.accentCoral.withOpacity(0.2)
                      : AppColors.primaryTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: profile.isBirthdayToday
                        ? AppColors.accentCoral
                        : AppColors.primaryTeal.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🎂', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Born ${profile.formattedDob}${profile.age != null ? " (${profile.age} yrs)" : ""}',
                            style: GoogleFonts.nunito(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: onSurface,
                            ),
                          ),
                          Text(
                            profile.isBirthdayToday
                                ? '🎉 Today is their Birthday! Wish them now!'
                                : 'Next birthday in ${profile.daysUntilNextBirthday} days',
                            style: GoogleFonts.nunito(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentCoralDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Detailed Profile Rows
            _buildDetailTile(
              icon: Icons.wc_rounded,
              label: 'Sex & Blood Group',
              value: [
                if (profile?.sex != null) profile!.sex!,
                if (profile?.bloodGroup != null)
                  'Blood: ${profile!.bloodGroup!}',
              ].join(' • '),
              onSurface: onSurface,
              secondaryColor: secondaryColor,
            ),
            _buildDetailTile(
              icon: Icons.location_city_rounded,
              label: 'Living Place / Residence City',
              value: profile?.livingPlace ?? profile?.city ?? '',
              onSurface: onSurface,
              secondaryColor: secondaryColor,
            ),
            _buildDetailTile(
              icon: Icons.home_rounded,
              label: 'Home / Residential Address',
              value: profile?.homeAddress ?? '',
              onSurface: onSurface,
              secondaryColor: secondaryColor,
            ),
            _buildDetailTile(
              icon: Icons.school_rounded,
              label: 'Education',
              value: profile?.education ?? '',
              onSurface: onSurface,
              secondaryColor: secondaryColor,
            ),
            _buildDetailTile(
              icon: Icons.work_rounded,
              label: 'Occupation & Working Place',
              value: [
                if (profile?.occupation != null &&
                    profile!.occupation!.isNotEmpty)
                  profile.occupation!,
                if (profile?.workingPlace != null &&
                    profile!.workingPlace!.isNotEmpty)
                  'at ${profile.workingPlace!}',
              ].join(' '),
              onSurface: onSurface,
              secondaryColor: secondaryColor,
            ),
            _buildDetailTile(
              icon: Icons.assignment_ind_rounded,
              label: 'Working Details',
              value: profile?.workingDetails ?? '',
              onSurface: onSurface,
              secondaryColor: secondaryColor,
            ),
            _buildDetailTile(
              icon: Icons.phone_rounded,
              label: 'Mobile Phone Number',
              value: profile?.phone ?? '',
              onSurface: onSurface,
              secondaryColor: secondaryColor,
            ),
            _buildDetailTile(
              icon: Icons.chat_rounded,
              label: 'WhatsApp Number',
              value: profile?.whatsappNumber ?? profile?.phone ?? '',
              onSurface: onSurface,
              secondaryColor: secondaryColor,
            ),
            if (profile?.bioDescription != null &&
                profile!.bioDescription!.isNotEmpty)
              _buildDetailTile(
                icon: Icons.notes_rounded,
                label: 'Family Bio / About',
                value: profile.bioDescription!,
                onSurface: onSurface,
                secondaryColor: secondaryColor,
              ),

            const SizedBox(height: 20),

            // Action Buttons
            if (isSelf)
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit My Family Profile'),
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/profile-setup?edit=true');
                },
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                    label: const Text('OurNest Chat'),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/chat/${member.userId}');
                    },
                  ),
                  if (profile?.phone != null && profile!.phone!.isNotEmpty)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call Mobile'),
                      onPressed: () => _callPhone(profile.phone!),
                    ),
                  if ((profile?.whatsappNumber != null &&
                          profile!.whatsappNumber!.isNotEmpty) ||
                      (profile?.phone != null && profile!.phone!.isNotEmpty))
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF128C7E),
                        side: const BorderSide(color: Color(0xFF25D366)),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('WhatsApp'),
                      onPressed: () => _openWhatsApp(
                          profile?.whatsappNumber ?? profile!.phone!),
                    ),
                  if ((profile?.homeAddress != null &&
                          profile!.homeAddress!.isNotEmpty) ||
                      (profile?.livingPlace != null &&
                          profile!.livingPlace!.isNotEmpty))
                    OutlinedButton.icon(
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: const Text('Map Address'),
                      onPressed: () => _openAddressInMaps(
                          profile?.homeAddress?.isNotEmpty == true
                              ? profile!.homeAddress!
                              : profile!.livingPlace!),
                    ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
    required Color onSurface,
    required Color secondaryColor,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: secondaryColor,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.nunito(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

