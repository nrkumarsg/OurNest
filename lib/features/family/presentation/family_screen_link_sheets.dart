part of 'family_screen.dart';

/// Connected Nests sheets: link a family, broadcast, family-to-family post
/// and Silent Curtain. Split out of family_screen.dart (audit F39); the code
/// is unchanged and still runs as part of [_FamilyScreenState].
extension _FamilyLinkSheets on _FamilyScreenState {
  void _showLinkFamilySheet(
    BuildContext context,
    Family myFamily, {
    String? initialCode,
    String? initialNameHint,
  }) {
    final codeCtrl = TextEditingController(text: initialCode ?? '');
    final nameHintCtrl = TextEditingController(text: initialNameHint ?? '');
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
      "Nephew / Niece's Family",
      "Cousin's Family",
      "In-Laws' Family",
      "Son / Daughter's Family",
    ];

    const friendPresets = [
      "Close Family Friends",
      "Tour Group / Travel Companions",
      "Custom Group / Special Circle",
      "Childhood Friend's Family",
      "Next-Door Neighbour Family",
      "Colleague's Family",
      "Single / Solo Friend",
    ];

    const communityPresets = [
      "Tour Group / Holiday Travel Circle",
      "Custom Community Group",
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
                        onPressed: () async {
                          final scanned = await Navigator.of(context)
                              .push<ParsedFamilyInvite>(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => const FamilyQrScannerModal(),
                            ),
                          );
                          if (scanned != null && ctx.mounted) {
                            setModalState(() {
                              codeCtrl.text = scanned.code;
                              if (scanned.familyName != null &&
                                  scanned.familyName!.isNotEmpty) {
                                nameHintCtrl.text = scanned.familyName!;
                              }
                            });
                          }
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
      '✈️ Tour Group & Travel Companions',
      '✨ Custom Group Circle',
      '⛪ Sunday Church Fellowship',
      '🛕 Temple Seva & Festival Volunteers',
      '👨‍👩‍👧‍👦 Close Blood Relatives',
      '🎉 Weekend Dinner & Friends Circle',
    ];

    const broadcastTemplates = [
      '✈️ Tour Group Update: Everyone please check today\'s tour itinerary and meet at the lobby 15 mins early! Reply 👍 when ready.',
      '✨ Custom Group Announcement: Important update for all members of our custom group!',
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
}
