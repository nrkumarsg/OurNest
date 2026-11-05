import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../../../core/constants/app_colors.dart';
import '../../chat/domain/chat_message_model.dart';
import '../../chat/presentation/chat_controller.dart';
import '../../profile/presentation/widgets/member_profile_sheet.dart';
import '../domain/family_link_model.dart';
import '../domain/family_member_model.dart';
import '../domain/family_model.dart';
import '../domain/relation_type.dart';
import 'family_controller.dart';
import 'widgets/family_qr_scanner_modal.dart';

/// Shows the real outcome of a family action (audit F07/U19): success only
/// when the server actually saved it, otherwise the reason it failed.
void showFamilyActionResult(
  BuildContext context,
  WidgetRef ref, {
  required bool ok,
  required String success,
}) {
  if (!context.mounted) return;
  final err = ref.read(familyControllerProvider).error;
  final String message;
  if (ok) {
    message = success;
  } else if (err is StateError) {
    message = err.message;
  } else if (err is PostgrestException) {
    message = err.message;
  } else {
    message = 'Something went wrong. Please check your connection and try again.';
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: ok ? AppColors.success : AppColors.error,
  ));
}

class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  void _showInviteModal(BuildContext context, Family family,
      {int initialTab = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FamilyQrScannerModal(
          family: family,
          initialTabIndex: initialTab,
        ),
      ),
    );
  }

  void _openMemberProfile(
    BuildContext context,
    FamilyMember member, {
    required bool isSelf,
    String? familyBranchName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MemberProfileSheet(
        member: member,
        isSelf: isSelf,
        familyBranchName: familyBranchName,
      ),
    );
  }

  void _showEditRelationSheet(
      BuildContext context, WidgetRef ref, FamilyMember member) {
    RelationType selected = member.relationType;
    final labelCtrl = TextEditingController(text: member.relationLabel);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Relation for ${member.displayName}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: RelationType.values.map((rel) {
                  final isSelected = selected == rel;
                  return ChoiceChip(
                    label: Text(
                      '${rel.emoji} ${rel.label}',
                      style: GoogleFonts.nunito(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(ctx).colorScheme.onSurface,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primaryTeal,
                    onSelected: (val) {
                      if (val) setModalState(() => selected = rel);
                    },
                  );
                }).toList(),
              ),
              if (selected == RelationType.other) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: labelCtrl,
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                      labelText: 'Custom Relation Label'),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await ref
                      .read(familyControllerProvider.notifier)
                      .updateMemberRelation(
                        familyId: member.familyId,
                        targetUserId: member.userId,
                        relation: selected.name,
                        relationLabel: labelCtrl.text.trim().isNotEmpty
                            ? labelCtrl.text.trim()
                            : null,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameFamilyDialog(
      BuildContext context, WidgetRef ref, Family family) {
    final nameCtrl = TextEditingController(text: family.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Family'),
        content: TextField(
          controller: nameCtrl,
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Theme.of(ctx).colorScheme.onSurface,
          ),
          decoration: const InputDecoration(labelText: 'Family Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                await ref
                    .read(familyControllerProvider.notifier)
                    .renameFamily(familyId: family.id, newName: newName);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveMember(
      BuildContext context, WidgetRef ref, FamilyMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${member.displayName}?'),
        content: Text(
            'Are you sure you want to remove ${member.displayName} (${member.formattedRelation}) from this family? They will no longer receive any messages.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref
                  .read(familyControllerProvider.notifier)
                  .removeMember(
                    familyId: member.familyId,
                    targetUserId: member.userId,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Remove',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveFamily(
      BuildContext context, WidgetRef ref, String familyId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Family?'),
        content: const Text(
            'Are you sure you want to leave this family circle? You will lose access to all messages.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref
                  .read(familyControllerProvider.notifier)
                  .leaveFamily(familyId);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                context.go('/family-entry');
              }
            },
            child: const Text('Leave',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showLinkFamilySheet(BuildContext context, Family myFamily) {
    final codeCtrl = TextEditingController();
    final nameHintCtrl = TextEditingController();
    String selectedRing = 'relative'; // 'relative' | 'friend' | 'community'
    String selectedBranch = "Brother's Family";
    String selectedPolicy = 'all_members';

    const relativePresets = [
      "Brother's Family",
      "Sister's Family",
      "Maternal Side (Mom's Family)",
      "Paternal Side (Dad's Family)",
      "Grandparents' Nest",
      "Uncle / Aunt's Family",
      "In-Laws' Family",
      "Cousin's Family",
    ];

    const friendPresets = [
      "Close Family Friends",
      "Childhood Friend's Family",
      "Next-Door Neighbour Family",
      "Colleague's Family",
      "Single / Solo Friend",
    ];

    const communityPresets = [
      "Temple Volunteers / Seva Group",
      "Church Fellowship / Parish Group",
      "Mosque / Prayer Community",
      "Charity & Service Volunteers",
      "Residents / Welfare Association",
      "Single Church / Temple Member",
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final onSurface = Theme.of(ctx).colorScheme.onSurface;
          final activePresets = selectedRing == 'community'
              ? communityPresets
              : selectedRing == 'friend'
                  ? friendPresets
                  : relativePresets;
          return Padding(
            padding: EdgeInsets.only(
              left: 22,
              right: 22,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        selectedRing == 'community'
                            ? Icons.volunteer_activism_rounded
                            : selectedRing == 'friend'
                                ? Icons.handshake_rounded
                                : Icons.account_tree_rounded,
                        color: AppColors.primaryTeal,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selectedRing == 'community'
                              ? 'Connect Church / Temple / Volunteer Group'
                              : selectedRing == 'friend'
                                  ? 'Connect Friend / Neighbour Family'
                                  : 'Link Relative Family to Tree',
                          style: GoogleFonts.nunito(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Three-Ring Selector: Blood Relatives vs Friend Families vs Church/Temple/Volunteers
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(
                          '🌳 Relative',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            color: selectedRing == 'relative'
                                ? Colors.white
                                : onSurface,
                          ),
                        ),
                        selected: selectedRing == 'relative',
                        selectedColor: AppColors.primaryTeal,
                        onSelected: (_) {
                          setModalState(() {
                            selectedRing = 'relative';
                            selectedBranch = relativePresets.first;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: Text(
                          '🤝 Friend',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            color: selectedRing == 'friend'
                                ? Colors.white
                                : onSurface,
                          ),
                        ),
                        selected: selectedRing == 'friend',
                        selectedColor: AppColors.accentCoral,
                        onSelected: (_) {
                          setModalState(() {
                            selectedRing = 'friend';
                            selectedBranch = friendPresets.first;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: Text(
                          '🛕⛪ Church / Temple / Volunteer',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            color: selectedRing == 'community'
                                ? Colors.white
                                : onSurface,
                          ),
                        ),
                        selected: selectedRing == 'community',
                        selectedColor: AppColors.info,
                        onSelected: (_) {
                          setModalState(() {
                            selectedRing = 'community';
                            selectedBranch = communityPresets.first;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedRing == 'community'
                        ? '🛕⛪ Community & Volunteer Ring: Connect Temple Seva groups, Church Fellowship circles, or individual single volunteers without exposing your private family chat!'
                        : selectedRing == 'friend'
                            ? '🔒 Friend Family Privacy Ring: Friend & Neighbour families only see their direct link with your family—they cannot browse your other blood relatives.'
                            : 'Connect another OurNest family into your Family Tree chain while keeping your daily nuclear chat private.',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            color: onSurface,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Family 6-Digit Invite Code *',
                            hintText: 'E.G. R9K2M4',
                            counterText: '',
                            prefixIcon: Icon(Icons.vpn_key_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 16),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Scan QR'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showInviteModal(context, myFamily, initialTab: 1);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameHintCtrl,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: selectedRing == 'community'
                          ? 'Church / Temple / Volunteer Group Name (Optional)'
                          : selectedRing == 'friend'
                              ? 'Friend / Neighbour Family Name (Optional)'
                              : 'Relative Family Name (Optional)',
                      hintText: selectedRing == 'community'
                          ? 'e.g., St. Mary\'s Youth Choir / Sri Mariamman Seva'
                          : 'e.g., Kumar Family / Chennai Nest',
                      prefixIcon: const Icon(Icons.home_work_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    selectedRing == 'community'
                        ? 'Select Community / Volunteer Category:'
                        : selectedRing == 'friend'
                            ? 'Select Friend / Neighbour Relationship:'
                            : 'Select Family Tree Relationship Branch:',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activePresets.map((branch) {
                      final isSelected = selectedBranch == branch;
                      final emoji = selectedRing == 'community'
                          ? '🛕⛪'
                          : selectedRing == 'friend'
                              ? '🤝'
                              : '🌿';
                      return ChoiceChip(
                        label: Text(
                          '$emoji $branch',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected ? Colors.white : onSurface,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: selectedRing == 'community'
                            ? AppColors.info
                            : selectedRing == 'friend'
                                ? AppColors.accentCoral
                                : AppColors.primaryTeal,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => selectedBranch = branch);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Who can send Family-to-Family messages & invitations?',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryTeal,
                    title: Text(
                      '👥 All Family Members (Recommended)',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                    ),
                    subtitle: const Text(
                        'Any member can send invitations, greetings, or chat across connected families'),
                    value: 'all_members',
                    groupValue: selectedPolicy,
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedPolicy = v);
                    },
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryTeal,
                    title: Text(
                      '👑 Family Admins Only (Father / Mother)',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                    ),
                    subtitle: const Text(
                        'Only Admins can broadcast official invitations between the two families'),
                    value: 'admins_only',
                    groupValue: selectedPolicy,
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedPolicy = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_link_rounded),
                    label: const Text('Connect to Family Tree'),
                    onPressed: () async {
                      final code = codeCtrl.text.trim().toUpperCase();
                      if (code.length < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Please enter the 6-character Invite Code of the relative family.'),
                          ),
                        );
                        return;
                      }
                      final ok = await ref
                          .read(familyControllerProvider.notifier)
                          .linkWithFamily(
                            myFamilyId: myFamily.id,
                            targetInviteCode: code,
                            branchLabel: selectedBranch,
                            targetFamilyNameHint: nameHintCtrl.text.trim(),
                            messagingPolicy: selectedPolicy,
                          );
                      if (ctx.mounted) {
                        if (ok) Navigator.pop(ctx);
                        showFamilyActionResult(
                          context,
                          ref,
                          ok: ok,
                          success:
                              '🌳 Request sent. It will show as connected once their admin approves it.',
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMultiGroupBroadcastSheet(
    BuildContext context,
    Family myFamily,
    List<FamilyLink> visibleLinks,
    bool isAdmin,
  ) {
    final activeBroadcastable = visibleLinks
        .where((l) => !l.isCurtainHidden && !l.isPeacePaused)
        .toList();
    String selectedRingFilter = 'all'; // 'all' | 'relative' | 'friend' | 'community' | 'custom'
    String selectedCustomCircle = '⛪ Sunday Church Fellowship';
    String deliveryScope = 'all_members'; // 'all_members' | 'admins_only'
    final selectedLinkIds =
        activeBroadcastable.map((l) => l.id).toSet();
    final msgCtrl = TextEditingController();

    const customCircles = [
      '⛪ Sunday Church Fellowship',
      '🛕 Temple Seva & Festival Volunteers',
      '👨‍👩‍👧‍👦 Close Blood Relatives',
      '🎉 Weekend Dinner & Friends Circle',
    ];

    const broadcastTemplates = [
      '🛕 Temple Seva Call: 🙏 Namaskaram! Reminder for tomorrow\'s Temple Seva & volunteer duty. Please reply 👍 to confirm your slot.',
      '⛪ Church Fellowship: ✝️ Praise the Lord! Reminder for our Sunday Parish Fellowship & Choir practice this week.',
      '🤲 Volunteer Roster Update: Please check your assigned volunteer timing and reach 15 mins early.',
      '🎉 Family Function Invitation: You and your family are warmly invited to join us this weekend!',
      '🎂 Birthday Celebration: Join our family for cake & dinner at 7:00 PM!',
      '🪔 Festival Greetings from ${"our circle"} to yours! Wishing everyone peace, joy & good health.',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final onSurface = Theme.of(ctx).colorScheme.onSurface;
          void applyFilter(String filter) {
            selectedRingFilter = filter;
            selectedLinkIds.clear();
            for (final l in activeBroadcastable) {
              if (filter == 'all') {
                selectedLinkIds.add(l.id);
              } else if (filter == 'relative' && l.ringType == 'relative') {
                selectedLinkIds.add(l.id);
              } else if (filter == 'friend' && l.ringType == 'friend') {
                selectedLinkIds.add(l.id);
              } else if (filter == 'community' && l.ringType == 'community') {
                selectedLinkIds.add(l.id);
              } else if (filter == 'custom') {
                selectedLinkIds.add(l.id);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 22,
              right: 22,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded,
                          color: AppColors.accentCoral, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Multi-Group & Volunteer Broadcast',
                              style: GoogleFonts.nunito(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                            ),
                            Text(
                              'Broadcast to Relatives, Friends, Church/Temple Volunteers, or Custom Circles',
                              style: GoogleFonts.nunito(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '1. Select Target Ring or Custom Circle:',
                    style: GoogleFonts.nunito(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('🌐 All Connected'),
                        selected: selectedRingFilter == 'all',
                        selectedColor: AppColors.primaryTeal,
                        labelStyle: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          color: selectedRingFilter == 'all'
                              ? Colors.white
                              : onSurface,
                        ),
                        onSelected: (_) =>
                            setModalState(() => applyFilter('all')),
                      ),
                      ChoiceChip(
                        label: const Text('🌳 Relatives Only'),
                        selected: selectedRingFilter == 'relative',
                        selectedColor: AppColors.primaryTeal,
                        labelStyle: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          color: selectedRingFilter == 'relative'
                              ? Colors.white
                              : onSurface,
                        ),
                        onSelected: (_) =>
                            setModalState(() => applyFilter('relative')),
                      ),
                      ChoiceChip(
                        label: const Text('🤝 Friends Only'),
                        selected: selectedRingFilter == 'friend',
                        selectedColor: AppColors.accentCoral,
                        labelStyle: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          color: selectedRingFilter == 'friend'
                              ? Colors.white
                              : onSurface,
                        ),
                        onSelected: (_) =>
                            setModalState(() => applyFilter('friend')),
                      ),
                      ChoiceChip(
                        label: const Text('🛕⛪ Church / Temple / Volunteers'),
                        selected: selectedRingFilter == 'community',
                        selectedColor: AppColors.info,
                        labelStyle: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          color: selectedRingFilter == 'community'
                              ? Colors.white
                              : onSurface,
                        ),
                        onSelected: (_) =>
                            setModalState(() => applyFilter('community')),
                      ),
                      ChoiceChip(
                        label: const Text('⭕ Saved Custom Circle'),
                        selected: selectedRingFilter == 'custom',
                        selectedColor: AppColors.accentCoralDark,
                        labelStyle: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          color: selectedRingFilter == 'custom'
                              ? Colors.white
                              : onSurface,
                        ),
                        onSelected: (_) =>
                            setModalState(() => applyFilter('custom')),
                      ),
                    ],
                  ),
                  if (selectedRingFilter == 'custom') ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: customCircles.map((c) {
                        final isSel = selectedCustomCircle == c;
                        return ChoiceChip(
                          label: Text(c, style: const TextStyle(fontSize: 12)),
                          selected: isSel,
                          selectedColor: AppColors.primaryTeal,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) =>
                              setModalState(() => selectedCustomCircle = c),
                        );
                      }).toList(),
                    ),
                  ],
                  if (activeBroadcastable.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 130),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppColors.primaryTeal.withOpacity(0.25)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: activeBroadcastable.map((link) {
                          final checked = selectedLinkIds.contains(link.id);
                          return CheckboxListTile(
                            dense: true,
                            activeColor: AppColors.primaryTeal,
                            value: checked,
                            onChanged: (v) {
                              setModalState(() {
                                if (v == true) {
                                  selectedLinkIds.add(link.id);
                                } else {
                                  selectedLinkIds.remove(link.id);
                                }
                              });
                            },
                            title: Text(
                              '${link.ringEmoji} ${link.connectedFamilyName}',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                            ),
                            subtitle: Text(
                              link.branchLabel,
                              style: GoogleFonts.nunito(fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '2. Delivery Audience Scope:',
                    style: GoogleFonts.nunito(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('🏠 All Members & Volunteers'),
                          selected: deliveryScope == 'all_members',
                          selectedColor: AppColors.primaryTeal,
                          labelStyle: GoogleFonts.nunito(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: deliveryScope == 'all_members'
                                ? Colors.white
                                : onSurface,
                          ),
                          onSelected: (_) => setModalState(
                              () => deliveryScope = 'all_members'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('👑 Admins / Leaders Only'),
                          selected: deliveryScope == 'admins_only',
                          selectedColor: AppColors.accentCoral,
                          labelStyle: GoogleFonts.nunito(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: deliveryScope == 'admins_only'
                                ? Colors.white
                                : onSurface,
                          ),
                          onSelected: (_) => setModalState(
                              () => deliveryScope = 'admins_only'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '3. 1-Tap Broadcast Templates (Temple / Church / Family):',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: broadcastTemplates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) {
                        final tpl = broadcastTemplates[idx];
                        return ActionChip(
                          label: Text(
                            tpl.length > 34 ? '${tpl.substring(0, 34)}...' : tpl,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () {
                            setModalState(() => msgCtrl.text = tpl);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: msgCtrl,
                    maxLines: 3,
                    style: GoogleFonts.nunito(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Broadcast Message / Announcement *',
                      hintText:
                          'Write your announcement for selected families, friends, or temple/church volunteers...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '🛡️ Silent Curtain Safety: Any hidden or peace-paused branch is automatically excluded.',
                    style: GoogleFonts.nunito(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCoral,
                    ),
                    icon: const Icon(Icons.campaign_rounded),
                    label: Text(
                      selectedRingFilter == 'custom'
                          ? 'Broadcast to $selectedCustomCircle'
                          : 'Send Broadcast (${selectedLinkIds.isEmpty ? "Selected Circle" : "${selectedLinkIds.length} Nests"})',
                    ),
                    onPressed: () async {
                      final text = msgCtrl.text.trim();
                      if (text.isEmpty) return;
                      final targetLabel = selectedRingFilter == 'custom'
                          ? selectedCustomCircle
                          : selectedRingFilter == 'community'
                              ? '🛕⛪ Church / Temple / Volunteer Groups'
                              : selectedRingFilter == 'friend'
                                  ? '🤝 Friend Families'
                                  : selectedRingFilter == 'relative'
                                      ? '🌳 Relative Families'
                                      : '🌐 All Connected Nests (${selectedLinkIds.length})';
                      final scopeLabel = deliveryScope == 'admins_only'
                          ? '👑 Admins/Coordinators Only'
                          : '🏠 All Members & Volunteers';
                      final formatted =
                          '📢 [Multi-Group Broadcast → $targetLabel ($scopeLabel)]\n$text';

                      final ok = await ref
                          .read(chatControllerProvider.notifier)
                          .sendMessage(
                            familyId: myFamily.id,
                            text: formatted,
                            audience: MessageAudience.all,
                          );

                      if (ctx.mounted) {
                        if (ok) Navigator.pop(ctx);
                        // Honest wording (F08): connected families do NOT
                        // receive this yet – it is posted in our own chat.
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? '📢 Posted in your family chat. Connected families don\'t receive broadcasts yet.'
                                : 'Not sent. Check your connection and try again.'),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.error,
                          ),
                        );
                        if (ok) context.push('/chat/family');
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFamilyToFamilyMessageSheet(
    BuildContext context,
    Family myFamily,
    FamilyLink link,
    bool isAdmin,
  ) {
    if (link.adminsOnly && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '👑 This family link is set to "Admins Only". Ask a Family Admin to send the cross-family invitation.'),
        ),
      );
      return;
    }

    final msgCtrl = TextEditingController();
    String targetMode = 'all'; // 'all' | 'admins' | 'individual'
    String? customRecipientName;
    final recipientCtrl = TextEditingController();

    const quickInvites = [
      '🎉 Family Function Invitation: You and your family are warmly invited to join us this weekend!',
      '🎂 Birthday Celebration: Join our family for cake & dinner at 7:00 PM!',
      '🪔 Festival Greetings from our family to yours! Wishing everyone joy & good health.',
      '🍽️ Family Get-Together Dinner at our home this Sunday!',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final onSurface = Theme.of(ctx).colorScheme.onSurface;
          return Padding(
            padding: EdgeInsets.only(
              left: 22,
              right: 22,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.send_to_mobile_rounded,
                          color: AppColors.accentCoral, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send to ${link.connectedFamilyName}',
                              style: GoogleFonts.nunito(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                            ),
                            Text(
                              '🌿 ${link.branchLabel} • From ${myFamily.name}',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Who should receive this in ${link.connectedFamilyName}?',
                    style: GoogleFonts.nunito(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(
                          '🏠 Entire Family',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: targetMode == 'all'
                                ? Colors.white
                                : onSurface,
                          ),
                        ),
                        selected: targetMode == 'all',
                        selectedColor: AppColors.primaryTeal,
                        onSelected: (_) =>
                            setModalState(() => targetMode = 'all'),
                      ),
                      ChoiceChip(
                        label: Text(
                          '👑 Family Admins Only',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: targetMode == 'admins'
                                ? Colors.white
                                : onSurface,
                          ),
                        ),
                        selected: targetMode == 'admins',
                        selectedColor: AppColors.primaryTeal,
                        onSelected: (_) =>
                            setModalState(() => targetMode = 'admins'),
                      ),
                      ChoiceChip(
                        label: Text(
                          '👤 Individual Relative',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: targetMode == 'individual'
                                ? Colors.white
                                : onSurface,
                          ),
                        ),
                        selected: targetMode == 'individual',
                        selectedColor: AppColors.primaryTeal,
                        onSelected: (_) =>
                            setModalState(() => targetMode = 'individual'),
                      ),
                    ],
                  ),
                  if (targetMode == 'individual') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: recipientCtrl,
                      onChanged: (v) => customRecipientName = v,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Relative Name (e.g., Uncle Ravi / Cousin Priya)',
                        prefixIcon: Icon(Icons.person_search_rounded),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    '1-Tap Family Invitation Templates:',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: quickInvites.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) {
                        final tpl = quickInvites[idx];
                        return ActionChip(
                          label: Text(
                            tpl.length > 36 ? '${tpl.substring(0, 36)}…' : tpl,
                            style: GoogleFonts.nunito(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                          onPressed: () {
                            setModalState(() {
                              msgCtrl.text = tpl;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: msgCtrl,
                    maxLines: 3,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Invitation or Family-to-Family Message',
                      hintText:
                          'Write your invitation, event announcement, or message...',
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCoral,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Post to Our Family Chat'),
                    onPressed: () async {
                      final body = msgCtrl.text.trim();
                      if (body.isEmpty) return;

                      final targetBadge = targetMode == 'admins'
                          ? '👑 Admins of ${link.connectedFamilyName}'
                          : targetMode == 'individual'
                              ? '👤 ${customRecipientName?.trim().isNotEmpty == true ? customRecipientName!.trim() : "Relative"} (${link.connectedFamilyName})'
                              : '🏠 All Members of ${link.connectedFamilyName}';

                      final formattedCrossMessage =
                          '🌳 [Family-to-Family • ${link.branchLabel} → $targetBadge]\n$body';

                      final ok = await ref
                          .read(chatControllerProvider.notifier)
                          .sendMessage(
                            familyId: myFamily.id,
                            text: formattedCrossMessage,
                            audience: MessageAudience.all,
                          );

                      if (ctx.mounted) {
                        if (ok) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Posted in your family chat. ${link.connectedFamilyName} doesn\'t receive it yet.'
                                : 'Not sent. Check your connection and try again.'),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.error,
                          ),
                        );
                        if (ok) context.push('/chat/family');
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSilentCurtainSheet(
    BuildContext context,
    FamilyLink link,
    bool isAdmin,
  ) {
    String selectedMode = link.visibilityMode; // 'visible' | 'peace_pause' | 'curtain_hidden'
    String selectedScope = link.hiddenScope == 'none'
        ? (isAdmin ? 'entire_family' : 'personal_only')
        : link.hiddenScope;
    bool hideUpdates = link.hideOurUpdates;
    int pauseDays = 30; // 7 | 30 | 0 (indefinite)

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final onSurface = Theme.of(ctx).colorScheme.onSurface;
          return Padding(
            padding: EdgeInsets.only(
              left: 22,
              right: 22,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.curtains_closed_rounded,
                          color: AppColors.primaryTeal, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Silent Curtain (Peace & Hide)',
                              style: GoogleFonts.nunito(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                            ),
                            Text(
                              '${link.connectedFamilyName} (${link.branchLabel})',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primaryTeal.withOpacity(0.25)),
                    ),
                    child: Text(
                      '✨ Better than WhatsApp Block: ${link.connectedFamilyName} will NEVER be notified. On their phone, the Family Tree link still looks normal—preventing drama and making future reconciliation effortless.',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '1. Choose Visibility / Peace Level:',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryTeal,
                    title: Text(
                      '🪟 Curtain Mode (Hide Family Completely)',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800, color: onSurface),
                    ),
                    subtitle: const Text(
                        'Completely hides this family from your Family Tree, Chat & Birthdays. Moves them into the discreet "Hidden Branches" drawer.'),
                    value: 'curtain_hidden',
                    groupValue: selectedMode,
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedMode = v);
                    },
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryTeal,
                    title: Text(
                      '🕊️ Peace Pause (Temporary Cooling-Off)',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800, color: onSurface),
                    ),
                    subtitle: const Text(
                        'Keeps them in the tree, but silently mutes their cross-family invitations & alerts while everyone cools off.'),
                    value: 'peace_pause',
                    groupValue: selectedMode,
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedMode = v);
                    },
                  ),
                  if (selectedMode == 'peace_pause') ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('7 Days'),
                            selected: pauseDays == 7,
                            selectedColor: AppColors.primaryTeal,
                            labelStyle: TextStyle(
                              color: pauseDays == 7 ? Colors.white : onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) =>
                                setModalState(() => pauseDays = 7),
                          ),
                          ChoiceChip(
                            label: const Text('30 Days'),
                            selected: pauseDays == 30,
                            selectedColor: AppColors.primaryTeal,
                            labelStyle: TextStyle(
                              color: pauseDays == 30 ? Colors.white : onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) =>
                                setModalState(() => pauseDays = 30),
                          ),
                          ChoiceChip(
                            label: const Text('Until I Unpause'),
                            selected: pauseDays == 0,
                            selectedColor: AppColors.primaryTeal,
                            labelStyle: TextStyle(
                              color: pauseDays == 0 ? Colors.white : onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) =>
                                setModalState(() => pauseDays = 0),
                          ),
                        ],
                      ),
                    ),
                  ],
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryTeal,
                    title: Text(
                      '🌳 Normal Visibility (Connected & Active)',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800, color: onSurface),
                    ),
                    subtitle: const Text(
                        'Full normal visibility in your Family Tree and invitations.'),
                    value: 'visible',
                    groupValue: selectedMode,
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedMode = v);
                    },
                  ),
                  if (selectedMode != 'visible') ...[
                    const Divider(height: 16),
                    Text(
                      '2. Who should this Hide / Pause apply to?',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (isAdmin)
                          ChoiceChip(
                            label: Text(
                              '🏠 My Entire Family',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700,
                                color: selectedScope == 'entire_family'
                                    ? Colors.white
                                    : onSurface,
                              ),
                            ),
                            selected: selectedScope == 'entire_family',
                            selectedColor: AppColors.primaryTeal,
                            onSelected: (_) => setModalState(
                                () => selectedScope = 'entire_family'),
                          ),
                        ChoiceChip(
                          label: Text(
                            '👤 Only On My Phone',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              color: selectedScope == 'personal_only'
                                  ? Colors.white
                                  : onSurface,
                            ),
                          ),
                          selected: selectedScope == 'personal_only',
                          selectedColor: AppColors.primaryTeal,
                          onSelected: (_) => setModalState(
                              () => selectedScope = 'personal_only'),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 18),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryTeal,
                    value: hideUpdates,
                    onChanged: (v) =>
                        setModalState(() => hideUpdates = v ?? false),
                    title: Text(
                      '🛡️ Privacy Shield (Hide Our Updates From Them)',
                      style: GoogleFonts.nunito(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                      ),
                    ),
                    subtitle: const Text(
                        'Do not share our family\'s invitations, status, working/living details, or birthday alerts with this family.'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (isAdmin)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.error),
                          icon: const Icon(Icons.link_off_rounded, size: 18),
                          label: const Text('Unlink Permanently'),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Unlink this family?'),
                                content: Text(
                                    '${link.connectedFamilyName} will be removed from your Family Tree. You would need a new request to connect again.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(dCtx, false),
                                      child: const Text('Keep')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(dCtx, true),
                                      child: const Text('Unlink',
                                          style: TextStyle(color: AppColors.error))),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            final ok = await ref
                                .read(familyControllerProvider.notifier)
                                .removeFamilyLink(link.id);
                            if (ctx.mounted && ok) Navigator.pop(ctx);
                            if (context.mounted) {
                              showFamilyActionResult(context, ref,
                                  ok: ok, success: 'Family unlinked.');
                            }
                          },
                        ),
                      const Spacer(),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Save Peace Setting'),
                        onPressed: () async {
                          final until = (selectedMode == 'peace_pause' &&
                                  pauseDays > 0)
                              ? DateTime.now().add(Duration(days: pauseDays))
                              : null;
                          final ok = await ref
                              .read(familyControllerProvider.notifier)
                              .updateFamilyPeaceMode(
                                linkId: link.id,
                                visibilityMode: selectedMode,
                                hiddenScope: selectedMode == 'visible'
                                    ? 'none'
                                    : selectedScope,
                                hideOurUpdates: hideUpdates,
                                pausedUntil: until,
                              );
                          if (ctx.mounted && ok) Navigator.pop(ctx);
                          if (context.mounted) {
                            showFamilyActionResult(
                              context,
                              ref,
                              ok: ok,
                              success: selectedMode == 'curtain_hidden'
                                  ? '🪟 ${link.connectedFamilyName} is now tucked behind the Silent Curtain.'
                                  : selectedMode == 'peace_pause'
                                      ? '🕊️ Peace Pause activated for ${link.connectedFamilyName}.'
                                      : '🌳 Restored normal visibility for ${link.connectedFamilyName}.',
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membershipAsync = ref.watch(currentMembershipProvider);
    final familyAsync = ref.watch(currentFamilyProvider);
    final activeMembers = ref.watch(activeMembersProvider);
    final pendingMembers = ref.watch(pendingMembersProvider);
    final familyLinksAsync = ref.watch(familyLinksProvider);

    return Scaffold(
      appBar: AppBar(
        title: familyAsync.when(
          data: (fam) => Text(fam?.name ?? 'My Family'),
          loading: () => const Text('Family'),
          error: (_, __) => const Text('Family'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.badge_rounded),
            tooltip: 'Edit My Personal Profile',
            onPressed: () => context.push('/profile-setup?edit=true'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Family & Tree',
            onPressed: () {
              ref.invalidate(currentMembershipProvider);
              ref.invalidate(currentFamilyProvider);
              ref.invalidate(familyMembersProvider);
              ref.invalidate(familyLinksProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Family QR & Scanner',
            onPressed: () {
              final fam = familyAsync.value;
              if (fam != null) _showInviteModal(context, fam);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentCoral,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.nunito(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
          tabs: const [
            Tab(text: '🏠 My Family'),
            Tab(text: '🌳 Family Tree'),
            Tab(text: '🎂 Birthdays'),
          ],
        ),
      ),
      body: SafeArea(
        child: membershipAsync.when(
          data: (membership) {
            if (membership == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/family-entry');
              });
              return const SizedBox.shrink();
            }

            final isAdmin = membership.isAdmin;
            final fam = familyAsync.value;
            final links = familyLinksAsync.value ?? [];

            return TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: MY NUCLEAR FAMILY + RICH PROFILES
                _buildMyFamilyTab(
                  context,
                  membership: membership,
                  fam: fam,
                  isAdmin: isAdmin,
                  activeMembers: activeMembers,
                  pendingMembers: pendingMembers,
                ),

                // TAB 2: CONNECTED FAMILY TREE (FAMILY-TO-FAMILY CHAIN)
                _buildFamilyTreeTab(
                  context,
                  membership: membership,
                  fam: fam,
                  isAdmin: isAdmin,
                  activeMembers: activeMembers,
                  links: links,
                ),

                // TAB 3: BIRTHDAYS & AGE REMINDERS
                _buildBirthdaysTab(
                  context,
                  membership: membership,
                  activeMembers: activeMembers,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading family: $e')),
        ),
      ),
    );
  }

  Widget _buildMyFamilyTab(
    BuildContext context, {
    required FamilyMember membership,
    required Family? fam,
    required bool isAdmin,
    required List<FamilyMember> activeMembers,
    required List<FamilyMember> pendingMembers,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fam != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.primaryTeal.withOpacity(0.12),
                      child: const Icon(
                        Icons.family_restroom_rounded,
                        size: 38,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            fam.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 20),
                            onPressed: () =>
                                _showRenameFamilyDialog(context, ref, fam),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Invite Code: ${fam.inviteCode}',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryTeal,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                            label: const Text('My QR'),
                            onPressed: () =>
                                _showInviteModal(context, fam, initialTab: 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.qr_code_scanner_rounded,
                                size: 20),
                            label: const Text('Scan QR'),
                            onPressed: () =>
                                _showInviteModal(context, fam, initialTab: 1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),

          // Pending Member Approvals (Admin)
          if (isAdmin && pendingMembers.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Pending Approvals',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentCoralDark,
                      ),
                ),
                const SizedBox(width: 8),
                Badge(
                  label: Text('${pendingMembers.length}'),
                  backgroundColor: AppColors.accentCoral,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...pendingMembers.map((pending) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: AppColors.accentCoral.withOpacity(0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              AppColors.accentCoral.withOpacity(0.2),
                          child: Text(
                            pending.displayName.isNotEmpty
                                ? pending.displayName[0].toUpperCase()
                                : '?',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pending.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              Text(
                                'Wants to join as: ${pending.formattedRelation}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 32),
                          tooltip: 'Approve',
                          onPressed: () {
                            ref
                                .read(familyControllerProvider.notifier)
                                .approveMember(
                                  familyId: pending.familyId,
                                  targetUserId: pending.userId,
                                );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_rounded,
                              color: AppColors.error, size: 32),
                          tooltip: 'Decline',
                          onPressed: () {
                            ref
                                .read(familyControllerProvider.notifier)
                                .removeMember(
                                  familyId: pending.familyId,
                                  targetUserId: pending.userId,
                                );
                          },
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 16),
          ],

          // Active Members Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Family Members (${activeMembers.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'Tap any person to view full profile, work, education & DOB',
                    style: GoogleFonts.nunito(
                      fontSize: 12.5,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Invite'),
                onPressed: () {
                  if (fam != null) _showInviteModal(context, fam);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...activeMembers.map((member) {
            final isSelf = member.userId == membership.userId;
            final p = member.profile;
            final avatarBytes = _decodeAvatar(p?.avatarUrl);

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openMemberProfile(
                  context,
                  member,
                  isSelf: isSelf,
                  familyBranchName: fam?.name,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14.0, vertical: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor:
                            AppColors.primaryTeal.withOpacity(0.12),
                        backgroundImage: avatarBytes != null
                            ? MemoryImage(avatarBytes)
                            : null,
                        child: avatarBytes == null
                            ? Text(
                                member.displayName.isNotEmpty
                                    ? member.displayName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.nunito(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryTeal,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  member.displayName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                if (isSelf)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryTeal
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'You',
                                      style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryTeal,
                                      ),
                                    ),
                                  ),
                                if (member.isAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentCoral
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Admin',
                                      style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.accentCoralDark,
                                      ),
                                    ),
                                  ),
                                if (p != null && p.isBirthdaySoon)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.22),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      p.isBirthdayToday
                                          ? '🎂 Today!'
                                          : '🎂 in ${p.daysUntilNextBirthday}d',
                                      style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              member.formattedRelation,
                              style: GoogleFonts.nunito(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                            if (p?.statusText != null &&
                                p!.statusText!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '"${p.statusText!}"',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                            if ((p?.livingPlace != null &&
                                    p!.livingPlace!.isNotEmpty) ||
                                (p?.workingPlace != null &&
                                    p!.workingPlace!.isNotEmpty)) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 10,
                                runSpacing: 2,
                                children: [
                                  if (p?.livingPlace != null &&
                                      p!.livingPlace!.isNotEmpty)
                                    Text(
                                      '📍 ${p.livingPlace!}',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  if (p?.workingPlace != null &&
                                      p!.workingPlace!.isNotEmpty)
                                    Text(
                                      '🏢 ${p.occupation != null && p.occupation!.isNotEmpty ? "${p.occupation} @ " : ""}${p.workingPlace!}',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isSelf)
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded,
                              color: AppColors.primaryTeal),
                          tooltip: 'Edit My Profile',
                          onPressed: () =>
                              context.push('/profile-setup?edit=true'),
                        )
                      else if (isAdmin)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (action) {
                            if (action == 'profile') {
                              _openMemberProfile(context, member,
                                  isSelf: isSelf, familyBranchName: fam?.name);
                            } else if (action == 'edit') {
                              _showEditRelationSheet(context, ref, member);
                            } else if (action == 'remove') {
                              _confirmRemoveMember(context, ref, member);
                            } else if (action == 'transfer') {
                              ref
                                  .read(familyControllerProvider.notifier)
                                  .transferAdmin(
                                    familyId: member.familyId,
                                    newAdminId: member.userId,
                                  );
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'profile',
                              child: Row(
                                children: [
                                  Icon(Icons.badge_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text('View Full Profile'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit Relation'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'transfer',
                              child: Row(
                                children: [
                                  Icon(Icons.stars_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text('Make Admin'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.person_remove_rounded,
                                      size: 20, color: AppColors.error),
                                  SizedBox(width: 8),
                                  Text('Remove',
                                      style:
                                          TextStyle(color: AppColors.error)),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondaryLight),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 24),
          if (!isAdmin)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              icon: const Icon(Icons.exit_to_app_rounded),
              label: const Text('Leave Family'),
              onPressed: () =>
                  _confirmLeaveFamily(context, ref, membership.familyId),
            ),
        ],
      ),
    );
  }

  Widget _buildFamilyTreeTab(
    BuildContext context, {
    required FamilyMember membership,
    required Family? fam,
    required bool isAdmin,
    required List<FamilyMember> activeMembers,
    required List<FamilyLink> links,
  }) {
    if (fam == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final visibleLinks =
        links.where((l) => !l.isCurtainHidden).toList();
    final curtainHiddenLinks =
        links.where((l) => l.isCurtainHidden).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Explanation Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryTeal.withOpacity(0.14),
                  AppColors.accentCoral.withOpacity(0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: AppColors.primaryTeal.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_tree_rounded,
                        color: AppColors.primaryTeal, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Connected Nests (Family-to-Family Chain)',
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '• Default messages stay private inside ${fam.name}.\n'
                  '• Connect 🌳 Relative Families, 🤝 Friend Families, or 🛕⛪ Church / Temple / Volunteer Groups (including single members) and send 1-tap broadcasts!',
                  style: GoogleFonts.nunito(
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_link_rounded),
                      label: const Text('Link Family / Friend / Temple / Church'),
                      onPressed: () => _showLinkFamilySheet(context, fam),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCoral,
                      ),
                      icon: const Icon(Icons.campaign_rounded),
                      label: const Text('📢 Broadcast & Custom Groups'),
                      onPressed: () => _showMultiGroupBroadcastSheet(
                        context,
                        fam,
                        visibleLinks,
                        isAdmin,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ROOT NODE: MY CORE FAMILY
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryTeal.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.home_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🏠 ${fam.name} (My Core Family)',
                            style: GoogleFonts.nunito(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${activeMembers.length} Members • Default Private Chat • Code: ${fam.inviteCode}',
                            style: GoogleFonts.nunito(
                              fontSize: 12.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: activeMembers.map((m) {
                    return ActionChip(
                      backgroundColor: Colors.white,
                      avatar: CircleAvatar(
                        backgroundColor: AppColors.primaryTeal,
                        child: Text(
                          m.displayName.isNotEmpty
                              ? m.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      label: Text(
                        '${m.displayName} (${m.relationType.label})',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                      onPressed: () => _openMemberProfile(
                        context,
                        m,
                        isSelf: m.userId == membership.userId,
                        familyBranchName: fam.name,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Visual Tree Connector Line
          Center(
            child: Container(
              width: 3,
              height: 28,
              color: AppColors.primaryTeal.withOpacity(0.45),
            ),
          ),

          if (visibleLinks.isEmpty && curtainHiddenLinks.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.holiday_village_rounded,
                      size: 48,
                      color: AppColors.primaryTeal.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Extended Families Linked Yet',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Connect your Brother\'s, Sister\'s, Parents\', or Relatives\' OurNest families to build your Family Tree chain and send invitations across families.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 13.5,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_link_rounded),
                      label: const Text('Connect First Relative Family'),
                      onPressed: () => _showLinkFamilySheet(context, fam),
                    ),
                  ],
                ),
              ),
            )
          else
            ...visibleLinks.map((link) {
              return Column(
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: link.isPending
                            ? AppColors.accentCoral
                            : AppColors.primaryTeal.withOpacity(0.35),
                        width: 1.4,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor:
                                    AppColors.accentCoral.withOpacity(0.15),
                                child: const Icon(
                                  Icons.diversity_3_rounded,
                                  color: AppColors.accentCoral,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            link.connectedFamilyName,
                                            style: GoogleFonts.nunito(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: link.isPending
                                                ? Colors.orange.withOpacity(0.2)
                                                : AppColors.success
                                                    .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            link.isPending
                                                ? 'Pending'
                                                : 'Connected',
                                            style: GoogleFonts.nunito(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: link.isPending
                                                  ? Colors.orange.shade900
                                                  : AppColors.success,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${link.isFriendFamily ? "🤝 Friend Circle" : "🌿 Family Tree"} • ${link.branchLabel}',
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: link.isFriendFamily
                                            ? AppColors.accentCoralDark
                                            : AppColors.primaryTeal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  link.isPeacePaused || link.hideOurUpdates
                                      ? Icons.visibility_off_rounded
                                      : Icons.curtains_rounded,
                                  color: AppColors.primaryTeal,
                                ),
                                tooltip:
                                    'Silent Curtain (Peace & Hide Mode — No Block Notification)',
                                onPressed: () => _showSilentCurtainSheet(
                                    context, link, isAdmin),
                              ),
                            ],
                          ),
                          if (link.isPeacePaused || link.hideOurUpdates) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.spa_rounded,
                                      size: 16, color: Colors.brown),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${link.peaceStatusLabel}${link.hideOurUpdates ? " • 🛡️ Privacy Shield On" : ""} (Silent to them)',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.brown.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          // Policy chip & switcher
                          Row(
                            children: [
                              Icon(
                                link.adminsOnly
                                    ? Icons.admin_panel_settings_rounded
                                    : Icons.groups_rounded,
                                size: 18,
                                color: AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  link.adminsOnly
                                      ? 'Policy: Only Family Admins can send cross-family invitations'
                                      : 'Policy: All Members can send cross-family invitations & messages',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ),
                              if (isAdmin)
                                TextButton(
                                  onPressed: () async {
                                    final nextPolicy = link.adminsOnly
                                        ? 'all_members'
                                        : 'admins_only';
                                    final ok = await ref
                                        .read(
                                            familyControllerProvider.notifier)
                                        .updateFamilyLinkPolicy(
                                            link.id, nextPolicy);
                                    if (context.mounted) {
                                      showFamilyActionResult(context, ref,
                                          ok: ok,
                                          success: nextPolicy == 'admins_only'
                                              ? 'Only admins can now message this family.'
                                              : 'All members can now message this family.');
                                    }
                                  },
                                  child: Text(
                                    link.adminsOnly
                                        ? 'Allow All'
                                        : 'Admins Only',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: (link.isPending &&
                                        link.isIncomingRequest &&
                                        isAdmin)
                                    ? ElevatedButton.icon(
                                        icon: const Icon(
                                            Icons.check_circle_rounded),
                                        label: const Text(
                                            'Approve Family Tree Connection'),
                                        onPressed: () async {
                                          final ok = await ref
                                              .read(familyControllerProvider
                                                  .notifier)
                                              .approveFamilyLink(link.id);
                                          if (context.mounted) {
                                            showFamilyActionResult(context, ref,
                                                ok: ok,
                                                success:
                                                    '🌳 ${link.connectedFamilyName} is now connected.');
                                          }
                                        },
                                      )
                                    : ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.accentCoral,
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.mail_rounded,
                                            size: 19),
                                        label: const Text(
                                            'Send Invitation / Message'),
                                        onPressed: () =>
                                            _showFamilyToFamilyMessageSheet(
                                          context,
                                          fam,
                                          link,
                                          isAdmin,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.curtains_closed_rounded,
                                    size: 18),
                                label: const Text('Hide / Peace'),
                                onPressed: () => _showSilentCurtainSheet(
                                    context, link, isAdmin),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 3,
                      height: 16,
                      color: AppColors.primaryTeal.withOpacity(0.35),
                    ),
                  ),
                ],
              );
            }),

          // DISCREET COLLAPSIBLE DRAWER FOR CURTAIN-HIDDEN BRANCHES
          if (curtainHiddenLinks.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).cardTheme.color?.withOpacity(0.85),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.primaryTeal.withOpacity(0.25),
                ),
              ),
              child: ExpansionTile(
                leading: const Icon(Icons.curtains_closed_rounded,
                    color: AppColors.primaryTeal),
                title: Text(
                  '🪟 Tucked Away / Hidden Branches (${curtainHiddenLinks.length})',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'Silently hidden on your side (Zero notification sent to them)',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                children: curtainHiddenLinks.map((hiddenLink) {
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.black12,
                      child: Icon(Icons.visibility_off_rounded, size: 18),
                    ),
                    title: Text(
                      hiddenLink.connectedFamilyName,
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${hiddenLink.branchLabel} • ${hiddenLink.peaceStatusLabel}',
                      style: GoogleFonts.nunito(fontSize: 12),
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.handshake_rounded, size: 16),
                      label: const Text('Lift Curtain'),
                      onPressed: () async {
                        final ok = await ref
                            .read(familyControllerProvider.notifier)
                            .updateFamilyPeaceMode(
                              linkId: hiddenLink.id,
                              visibilityMode: 'visible',
                              hiddenScope: 'none',
                              hideOurUpdates: false,
                              pausedUntil: null,
                            );
                        if (context.mounted) {
                          showFamilyActionResult(context, ref,
                              ok: ok,
                              success:
                                  '🤝 Restored ${hiddenLink.connectedFamilyName} back to your Family Tree!');
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBirthdaysTab(
    BuildContext context, {
    required FamilyMember membership,
    required List<FamilyMember> activeMembers,
  }) {
    final withBirthdays = activeMembers
        .where((m) => m.profile?.dateOfBirth != null)
        .toList()
      ..sort((a, b) => (a.profile!.daysUntilNextBirthday ?? 999)
          .compareTo(b.profile!.daysUntilNextBirthday ?? 999));

    final withoutBirthdays =
        activeMembers.where((m) => m.profile?.dateOfBirth == null).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.amber.shade700.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Text('🎂', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family Tree Birthday Reminders',
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Automatic countdowns & 1-tap birthday wishes for every member in your family circle.',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (withBirthdays.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.cake_rounded,
                        size: 48, color: AppColors.accentCoral),
                    const SizedBox(height: 12),
                    Text(
                      'No Birthdays Added Yet',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add your Date of Birth in your Personal Profile so your family never misses a birthday!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 13.5,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit_calendar_rounded),
                      label: const Text('Add My Date of Birth'),
                      onPressed: () =>
                          context.push('/profile-setup?edit=true'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...withBirthdays.map((m) {
              final p = m.profile!;
              final days = p.daysUntilNextBirthday ?? 0;
              final nextAge = (p.age ?? 0) + (days == 0 ? 0 : 1);
              final isToday = p.isBirthdayToday;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isToday ? Colors.amber.withOpacity(0.15) : null,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor:
                                AppColors.accentCoral.withOpacity(0.16),
                            child: Text(
                              isToday ? '🎉' : '🎂',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.displayName,
                                  style: GoogleFonts.nunito(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${m.formattedRelation} • Born ${p.formattedDob}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isToday
                                      ? '🥳 Turning $nextAge Today!'
                                      : 'Turns $nextAge in $days days (${p.formattedBirthdayShort})',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: isToday
                                        ? AppColors.accentCoralDark
                                        : AppColors.primaryTeal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentCoral,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.celebration_rounded,
                                  size: 18),
                              label: const Text('Send Birthday Wish 🎂'),
                              onPressed: () async {
                                await ref
                                    .read(chatControllerProvider.notifier)
                                    .sendMessage(
                                      familyId: membership.familyId,
                                      text:
                                          '🎂🎉 Happy Birthday ${m.displayName}! Wishing you wonderful health, happiness, and love from all of us in the family! ❤️🥳',
                                      audience: MessageAudience.all,
                                    );
                                if (context.mounted) {
                                  context.push('/chat/family');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.person_rounded, size: 18),
                            label: const Text('Profile'),
                            onPressed: () => _openMemberProfile(
                              context,
                              m,
                              isSelf: m.userId == membership.userId,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

          if (withoutBirthdays.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Members Without Birthday Set (${withoutBirthdays.length})',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            ...withoutBirthdays.map((m) {
              final isSelf = m.userId == membership.userId;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryTeal.withOpacity(0.12),
                  child: Text(
                    m.displayName.isNotEmpty
                        ? m.displayName[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(m.displayName),
                subtitle: Text(m.formattedRelation),
                trailing: isSelf
                    ? TextButton.icon(
                        icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                        label: const Text('Add My DOB'),
                        onPressed: () =>
                            context.push('/profile-setup?edit=true'),
                      )
                    : null,
              );
            }),
          ],
        ],
      ),
    );
  }
}
