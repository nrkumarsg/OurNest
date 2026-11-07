import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../chat/domain/chat_message_model.dart';
import '../../../chat/presentation/chat_controller.dart';
import '../../domain/family_member_model.dart';
import '../../domain/family_model.dart';
import '../family_controller.dart';

class CustomSubgroup {
  final String id;
  final String name;
  final String category; // 'tour' | 'temple' | 'church' | 'friends' | 'custom'
  final String creatorUserId;
  final List<String> adminUserIds;
  final List<String> memberUserIds;

  const CustomSubgroup({
    required this.id,
    required this.name,
    required this.category,
    required this.creatorUserId,
    required this.adminUserIds,
    required this.memberUserIds,
  });

  String get emoji {
    switch (category) {
      case 'tour':
        return '✈️';
      case 'temple':
        return '🛕';
      case 'church':
        return '⛪';
      case 'friends':
        return '🤝';
      default:
        return '✨';
    }
  }

  bool isUserAdmin(String userId) =>
      creatorUserId == userId || adminUserIds.contains(userId);

  CustomSubgroup copyWith({
    String? name,
    String? category,
    List<String>? adminUserIds,
    List<String>? memberUserIds,
  }) {
    return CustomSubgroup(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      creatorUserId: creatorUserId,
      adminUserIds: adminUserIds ?? this.adminUserIds,
      memberUserIds: memberUserIds ?? this.memberUserIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'creatorUserId': creatorUserId,
        'adminUserIds': adminUserIds,
        'memberUserIds': memberUserIds,
      };

  factory CustomSubgroup.fromJson(Map<String, dynamic> json) {
    return CustomSubgroup(
      id: json['id'] as String? ?? 'grp_default',
      name: json['name'] as String? ?? 'Custom Group',
      category: json['category'] as String? ?? 'custom',
      creatorUserId: json['creatorUserId'] as String? ?? '',
      adminUserIds: (json['adminUserIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      memberUserIds: (json['memberUserIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class CustomGroupSheet extends ConsumerStatefulWidget {
  final Family family;
  final FamilyMember currentMembership;
  final List<FamilyMember> activeMembers;

  const CustomGroupSheet({
    super.key,
    required this.family,
    required this.currentMembership,
    required this.activeMembers,
  });

  static Future<void> show(
    BuildContext context, {
    required Family family,
    required FamilyMember currentMembership,
    required List<FamilyMember> activeMembers,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => CustomGroupSheet(
        family: family,
        currentMembership: currentMembership,
        activeMembers: activeMembers,
      ),
    );
  }

  @override
  ConsumerState<CustomGroupSheet> createState() => _CustomGroupSheetState();
}

class _CustomGroupSheetState extends ConsumerState<CustomGroupSheet> {
  List<CustomSubgroup> _groups = [];
  bool _loading = true;
  bool _creatingNew = false;

  String _selectedCategory = 'tour';
  final _nameCtrl = TextEditingController(text: 'Family Holiday Tour Group');
  final Set<String> _selectedMembers = {};
  final Set<String> _selectedCoAdmins = {};

  static const _categories = [
    ('tour', '✈️ Tour Group', 'Family Holiday Tour Group'),
    ('custom', '✨ Custom Group', 'Our Special Custom Group'),
    ('temple', '🛕 Temple Group', 'Temple Seva & Pilgrimage Group'),
    ('church', '⛪ Church Group', 'Sunday Church Fellowship Group'),
    ('friends', '🤝 Friends Group', 'Close Friends & Outing Circle'),
  ];

  static const _storage = FlutterSecureStorage();
  String get _prefsKey => 'ournest_custom_groups_${widget.family.id}';

  @override
  void initState() {
    super.initState();
    for (final m in widget.activeMembers) {
      _selectedMembers.add(m.userId);
      if (m.isAdmin || m.userId == widget.currentMembership.userId) {
        _selectedCoAdmins.add(m.userId);
      }
    }
    _loadGroups();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    String? raw;
    try {
      raw = await _storage.read(key: _prefsKey);
    } catch (_) {}
    final allIds = widget.activeMembers.map((m) => m.userId).toList();
    final adminIds = widget.activeMembers
        .where((m) => m.isAdmin)
        .map((m) => m.userId)
        .toList();
    if (!adminIds.contains(widget.currentMembership.userId)) {
      adminIds.add(widget.currentMembership.userId);
    }

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        setState(() {
          _groups = decoded
              .map((e) =>
                  CustomSubgroup.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _loading = false;
        });
        return;
      } catch (_) {}
    }

    // Seed default preset groups including Tour Group and Custom Group
    final defaults = [
      CustomSubgroup(
        id: 'grp_tour_default',
        name: '✈️ Tour & Travel Group',
        category: 'tour',
        creatorUserId: widget.currentMembership.userId,
        adminUserIds: adminIds,
        memberUserIds: allIds,
      ),
      CustomSubgroup(
        id: 'grp_custom_default',
        name: '✨ Custom Family Sub-Group',
        category: 'custom',
        creatorUserId: widget.currentMembership.userId,
        adminUserIds: adminIds,
        memberUserIds: allIds,
      ),
    ];
    await _saveGroups(defaults);
  }

  Future<void> _saveGroups(List<CustomSubgroup> next) async {
    try {
      await _storage.write(
        key: _prefsKey,
        value: jsonEncode(next.map((g) => g.toJson()).toList()),
      );
    } catch (_) {}
    if (mounted) {
      setState(() {
        _groups = next;
        _loading = false;
      });
    }
  }

  Future<void> _createGroup() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final myId = widget.currentMembership.userId;
    final members = {..._selectedMembers, myId}.toList();
    final admins = {..._selectedCoAdmins, myId}.toList();

    final newGrp = CustomSubgroup(
      id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: _selectedCategory,
      creatorUserId: myId,
      adminUserIds: admins,
      memberUserIds: members,
    );
    final updated = [newGrp, ..._groups];
    await _saveGroups(updated);

    // Also sync shared admin roles in family if current user is Family Admin
    if (widget.currentMembership.isAdmin) {
      for (final uid in admins) {
        if (uid != myId) {
          await ref.read(familyControllerProvider.notifier).setMemberAdminRole(
                familyId: widget.family.id,
                targetUserId: uid,
                makeAdmin: true,
              );
        }
      }
    }

    if (mounted) {
      setState(() => _creatingNew = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${newGrp.emoji} Created "$name" with ${admins.length} Shared Admin(s)!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _toggleGroupCoAdmin(
      CustomSubgroup group, FamilyMember target) async {
    final myId = widget.currentMembership.userId;
    if (!group.isUserAdmin(myId) && !widget.currentMembership.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only an Admin or Shared Admin can grant Admin rights.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final currentAdmins = {...group.adminUserIds};
    final willBeAdmin = !currentAdmins.contains(target.userId);
    if (willBeAdmin) {
      currentAdmins.add(target.userId);
    } else if (currentAdmins.length > 1) {
      currentAdmins.remove(target.userId);
    } else {
      return;
    }

    final updated = _groups
        .map((g) => g.id == group.id
            ? g.copyWith(adminUserIds: currentAdmins.toList())
            : g)
        .toList();
    await _saveGroups(updated);

    if (widget.currentMembership.isAdmin) {
      await ref.read(familyControllerProvider.notifier).setMemberAdminRole(
            familyId: widget.family.id,
            targetUserId: target.userId,
            makeAdmin: willBeAdmin,
          );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(willBeAdmin
              ? '👑 Shared Admin rights granted to ${target.displayName}!'
              : 'Removed Shared Admin rights from ${target.displayName}.'),
          backgroundColor: AppColors.primaryTeal,
        ),
      );
    }
  }

  Future<void> _sendGroupMessageDialog(CustomSubgroup group) async {
    final ctrl = TextEditingController(
      text: group.category == 'tour'
          ? '✈️ [${group.name}] Tour Update: Please check our itinerary and meeting time!'
          : '${group.emoji} [${group.name}] Group Update: ',
    );
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${group.emoji} Post to ${group.name}'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Group Message (E2EE Selected Audience)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send to Group'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (sent == true && ctrl.text.trim().isNotEmpty) {
      await ref.read(chatControllerProvider.notifier).sendMessage(
            familyId: widget.family.id,
            text: ctrl.text.trim(),
            audience: MessageAudience.selected,
            selectedRecipientIds: group.memberUserIds,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${group.emoji} Sent encrypted message to ${group.name} (${group.memberUserIds.length} members)!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? const Color(0xFFF5F7F7) : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? const Color(0xFFCFD8DC) : AppColors.textSecondaryLight;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_2_rounded,
                    color: AppColors.primaryTeal, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Groups, Tour Groups & Shared Admins',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Create custom or tour groups and share Admin rights with others',
                        style: GoogleFonts.nunito(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!_creatingNew)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCoral,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text(
                    'Create Custom Group / ✈️ Tour Group + Share Admin'),
                onPressed: () => setState(() => _creatingNew = true),
              )
            else
              _buildCreateForm(textPrimary, textSecondary),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ..._groups.map((g) => _buildGroupCard(g, textPrimary, textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateForm(Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryTeal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryTeal.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '1. Choose Group Type (Standard or Custom):',
            style: GoogleFonts.nunito(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final isSel = _selectedCategory == cat.$1;
              return ChoiceChip(
                label: Text(cat.$2),
                selected: isSel,
                selectedColor: AppColors.primaryTeal,
                labelStyle: GoogleFonts.nunito(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isSel ? Colors.white : textPrimary,
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedCategory = cat.$1;
                    _nameCtrl.text = cat.$3;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
            decoration: const InputDecoration(
              labelText: 'Custom / Tour Group Name',
              hintText: 'e.g., Malaysia Tour 2026 / Cousins Custom Group',
              prefixIcon: Icon(Icons.edit_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '2. Select Members & Grant Shared Admin (👑 Co-Admin) Rights:',
            style: GoogleFonts.nunito(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ...widget.activeMembers.map((m) {
            final isMe = m.userId == widget.currentMembership.userId;
            final inGroup = _selectedMembers.contains(m.userId) || isMe;
            final isCoAdmin = _selectedCoAdmins.contains(m.userId) || isMe;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Checkbox(
                    value: inGroup,
                    activeColor: AppColors.primaryTeal,
                    onChanged: isMe
                        ? null
                        : (v) {
                            setState(() {
                              if (v == true) {
                                _selectedMembers.add(m.userId);
                              } else {
                                _selectedMembers.remove(m.userId);
                                _selectedCoAdmins.remove(m.userId);
                              }
                            });
                          },
                  ),
                  Expanded(
                    child: Text(
                      '${m.displayName} (${m.formattedRelation})',
                      style: GoogleFonts.nunito(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  FilterChip(
                    label: Text(
                      isCoAdmin ? '👑 Admin' : '+ Share Admin',
                      style: GoogleFonts.nunito(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isCoAdmin ? Colors.white : textPrimary,
                      ),
                    ),
                    selected: isCoAdmin,
                    selectedColor: AppColors.accentCoral,
                    onSelected: isMe
                        ? null
                        : (v) {
                            setState(() {
                              if (v) {
                                _selectedMembers.add(m.userId);
                                _selectedCoAdmins.add(m.userId);
                              } else {
                                _selectedCoAdmins.remove(m.userId);
                              }
                            });
                          },
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _creatingNew = false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Save Group & Admins'),
                onPressed: _createGroup,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
      CustomSubgroup group, Color textPrimary, Color textSecondary) {
    final canManageAdmins =
        group.isUserAdmin(widget.currentMembership.userId) ||
            widget.currentMembership.isAdmin;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(group.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '${group.memberUserIds.length} members • ${group.adminUserIds.length} Shared Admin(s)',
                        style: GoogleFonts.nunito(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Message'),
                  onPressed: () => _sendGroupMessageDialog(group),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Tap any member below to Share / Toggle Admin rights (👑 Co-Admin):',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.activeMembers.map((m) {
                final isGrpAdmin = group.isUserAdmin(m.userId);
                return ActionChip(
                  avatar: Icon(
                    isGrpAdmin
                        ? Icons.workspace_premium_rounded
                        : Icons.person_outline_rounded,
                    size: 16,
                    color: isGrpAdmin
                        ? AppColors.accentCoral
                        : AppColors.primaryTeal,
                  ),
                  label: Text(
                    isGrpAdmin
                        ? '${m.displayName} (👑 Admin)'
                        : '${m.displayName} (+ Share Admin)',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  onPressed: canManageAdmins
                      ? () => _toggleGroupCoAdmin(group, m)
                      : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

