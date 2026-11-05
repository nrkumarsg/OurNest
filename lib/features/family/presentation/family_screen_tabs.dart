part of 'family_screen.dart';

/// The three tabs of the Family screen (My Family, Family Tree, Birthdays).
/// Split out of family_screen.dart (audit F39); the code is unchanged.
extension _FamilyScreenTabs on _FamilyScreenState {
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
                                  if (p.livingPlace != null &&
                                      p.livingPlace!.isNotEmpty)
                                    Text(
                                      '📍 ${p.livingPlace!}',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  if (p.workingPlace != null &&
                                      p.workingPlace!.isNotEmpty)
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
