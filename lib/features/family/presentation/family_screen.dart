import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/friendly_error.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/domain/chat_message_model.dart';
import '../../chat/presentation/chat_controller.dart';
import '../../profile/presentation/widgets/member_profile_sheet.dart';
import '../domain/family_link_model.dart';
import '../domain/family_member_model.dart';
import '../domain/family_model.dart';
import '../domain/relation_type.dart';
import 'family_controller.dart';
import 'widgets/custom_group_sheet.dart';
import 'widgets/family_qr_scanner_modal.dart';


part 'family_screen_link_sheets.dart';
part 'family_screen_tabs.dart';

/// Shows the real outcome of a family action (audit F07/U19): success only
/// when the server actually saved it, otherwise the reason it failed.
void showFamilyActionResult(
  BuildContext context,
  WidgetRef ref, {
  required bool ok,
  required String success,
}) {
  if (!context.mounted) return;
  final message =
      ok ? success : friendlyError(ref.read(familyControllerProvider).error);
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
    final adminMember = ref
        .read(activeMembersProvider)
        .where((m) => m.isAdmin && m.profile != null)
        .firstOrNull;
    final adminProfile = adminMember?.profile;
    Navigator.of(context).push<ParsedFamilyInvite>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FamilyQrScannerModal(
          family: family,
          adminCity: adminProfile?.livingPlace ?? adminProfile?.city,
          adminAddress: adminProfile?.homeAddress,
          initialTabIndex: initialTab,
          onInviteScanned: (parsed) {
            if (!context.mounted) return;
            _showLinkFamilySheet(
              context,
              family,
              initialCode: parsed.code,
              initialNameHint: parsed.familyName,
            );
          },
          onResetInviteCode: (ref.read(currentMembershipProvider).value?.isAdmin ?? false)
              ? () async {
                  final code = await ref
                      .read(familyControllerProvider.notifier)
                      .regenerateInviteCode(family.id);
                  if (code == null && context.mounted) {
                    showFamilyActionResult(context, ref, ok: false, success: '');
                  }
                  return code;
                }
              : null,
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
              final ok = await ref
                  .read(familyControllerProvider.notifier)
                  .removeMember(
                    familyId: member.familyId,
                    targetUserId: member.userId,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                showFamilyActionResult(context, ref,
                    ok: ok, success: '${member.displayName} was removed.');
              }
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
              final ok = await ref
                  .read(familyControllerProvider.notifier)
                  .leaveFamily(familyId);
              if (ctx.mounted) Navigator.pop(ctx);
              if (!context.mounted) return;
              if (ok) {
                context.go('/family-entry');
              } else {
                // e.g. Q4: the only admin must hand over the role first.
                showFamilyActionResult(context, ref, ok: false, success: '');
              }
            },
            child: const Text('Leave',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
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

}
