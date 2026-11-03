class FamilyLink {
  final String id;
  final String requesterFamilyId;
  final String targetFamilyId;
  final String connectedFamilyId;
  final String connectedFamilyName;
  final String connectedInviteCode;
  final String branchLabel; // e.g. "Brother's Family", "Maternal Side", "Paternal Grandparents"
  final String messagingPolicy; // 'all_members' or 'admins_only'
  final String status; // 'pending' or 'active'
  final bool isIncomingRequest;
  final DateTime createdAt;

  // --- Silent Curtain (Peace & Hide Mode — Non-Block Family Harmony) ---
  /// 'visible' | 'peace_pause' | 'curtain_hidden'
  final String visibilityMode;
  /// 'none' | 'entire_family' | 'personal_only'
  final String hiddenScope;
  /// Whether our family's profile updates, birthdays & invitations are shielded from this family
  final bool hideOurUpdates;
  /// Optional cooling-off expiration timestamp (e.g. 7 days or 30 days)
  final DateTime? pausedUntil;

  const FamilyLink({
    required this.id,
    required this.requesterFamilyId,
    required this.targetFamilyId,
    required this.connectedFamilyId,
    required this.connectedFamilyName,
    required this.connectedInviteCode,
    required this.branchLabel,
    this.messagingPolicy = 'all_members',
    this.status = 'active',
    this.isIncomingRequest = false,
    required this.createdAt,
    this.visibilityMode = 'visible',
    this.hiddenScope = 'none',
    this.hideOurUpdates = false,
    this.pausedUntil,
  });

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isAdminsOnly => messagingPolicy == 'admins_only';
  bool get adminsOnly => isAdminsOnly;

  bool get isCurtainHidden => visibilityMode == 'curtain_hidden';
  bool get isPeacePaused => visibilityMode == 'peace_pause';
  bool get isNormalVisible => visibilityMode == 'visible';

  bool get isCommunityGroup {
    final lower = branchLabel.toLowerCase();
    return lower.contains('temple') ||
        lower.contains('church') ||
        lower.contains('mosque') ||
        lower.contains('volunteer') ||
        lower.contains('seva') ||
        lower.contains('parish') ||
        lower.contains('fellowship') ||
        lower.contains('charity') ||
        lower.contains('welfare');
  }

  bool get isFriendFamily {
    if (isCommunityGroup) return false;
    final lower = branchLabel.toLowerCase();
    return lower.contains('friend') ||
        lower.contains('neighbour') ||
        lower.contains('neighbor') ||
        lower.contains('colleague') ||
        lower.contains('community');
  }

  String get ringType {
    if (isCommunityGroup) return 'community';
    if (isFriendFamily) return 'friend';
    return 'relative';
  }

  String get ringEmoji {
    if (isCommunityGroup) return '🛕⛪';
    if (isFriendFamily) return '🤝';
    return '🌳';
  }

  String get peaceStatusLabel {
    if (isCurtainHidden) {
      return hiddenScope == 'personal_only'
          ? '🪟 Hidden on My Screen (Curtain Mode)'
          : '🪟 Hidden for Whole Family (Curtain Mode)';
    }
    if (isPeacePaused) {
      if (pausedUntil != null) {
        final daysLeft = pausedUntil!.difference(DateTime.now()).inDays + 1;
        return '🕊️ Peace Pause (${daysLeft > 0 ? "${daysLeft}d left" : "Active"})';
      }
      return '🕊️ Peace Pause (Quiet Mode)';
    }
    if (hideOurUpdates) {
      return '🛡️ Privacy Shield Active';
    }
    return 'Visible in Family Tree';
  }

  FamilyLink copyWith({
    String? branchLabel,
    String? messagingPolicy,
    String? status,
    String? visibilityMode,
    String? hiddenScope,
    bool? hideOurUpdates,
    DateTime? pausedUntil,
    bool clearPausedUntil = false,
  }) {
    return FamilyLink(
      id: id,
      requesterFamilyId: requesterFamilyId,
      targetFamilyId: targetFamilyId,
      connectedFamilyId: connectedFamilyId,
      connectedFamilyName: connectedFamilyName,
      connectedInviteCode: connectedInviteCode,
      branchLabel: branchLabel ?? this.branchLabel,
      messagingPolicy: messagingPolicy ?? this.messagingPolicy,
      status: status ?? this.status,
      isIncomingRequest: isIncomingRequest,
      createdAt: createdAt,
      visibilityMode: visibilityMode ?? this.visibilityMode,
      hiddenScope: hiddenScope ?? this.hiddenScope,
      hideOurUpdates: hideOurUpdates ?? this.hideOurUpdates,
      pausedUntil: clearPausedUntil ? null : (pausedUntil ?? this.pausedUntil),
    );
  }
}
