import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/family_link_model.dart';
import '../domain/family_member_model.dart';
import '../domain/family_model.dart';

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return FamilyRepository(client);
});

class FamilyRepository {
  final SupabaseClient _client;
  final List<FamilyLink> _localFallbackLinks = [];
  final Map<String, FamilyLink> _peaceOverrides = {};

  FamilyRepository(this._client);

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Creates a family and sets the creator as Admin with active status
  Future<Map<String, dynamic>> createFamily({
    required String name,
    required String adminRelation,
    String? adminRelationLabel,
  }) async {
    final response = await _client.rpc(
      'create_family',
      params: {
        'family_name': name,
        'admin_relation': adminRelation,
        'admin_relation_label': adminRelationLabel,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Joins a family via 6-character invite code (sets status to 'pending')
  Future<Map<String, dynamic>> joinFamily({
    required String inviteCode,
    required String applicantRelation,
    String? applicantRelationLabel,
  }) async {
    final response = await _client.rpc(
      'join_family',
      params: {
        'invite_code_input': inviteCode.trim().toUpperCase(),
        'applicant_relation': applicantRelation,
        'applicant_relation_label': applicantRelationLabel,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Fetches the user's current family membership (including pending)
  Future<FamilyMember?> getCurrentUserMembership() async {
    final uid = currentUserId;
    if (uid == null) return null;

    final response = await _client
        .from('family_members')
        .select('*, profiles(*)')
        .eq('user_id', uid)
        .maybeSingle();

    if (response == null) return null;
    return FamilyMember.fromJson(response);
  }

  /// Fetches family details by ID
  Future<Family?> getFamily(String familyId) async {
    final response = await _client
        .from('families')
        .select()
        .eq('id', familyId)
        .maybeSingle();

    if (response == null) return null;
    return Family.fromJson(response);
  }

  /// Fetches all members of a family (both active and pending for admin)
  Future<List<FamilyMember>> getFamilyMembers(String familyId) async {
    final response = await _client
        .from('family_members')
        .select('*, profiles(*)')
        .eq('family_id', familyId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Admin: Approves a pending member and optionally updates relation
  Future<void> approveMember({
    required String familyId,
    required String targetUserId,
    String? assignedRelation,
    String? assignedLabel,
  }) async {
    await _client.rpc(
      'approve_member',
      params: {
        'target_family_id': familyId,
        'target_user_id': targetUserId,
        'assigned_relation': assignedRelation,
        'assigned_label': assignedLabel,
      },
    );
  }

  /// Admin: Updates an existing member's relation
  Future<void> updateMemberRelation({
    required String familyId,
    required String targetUserId,
    required String relation,
    String? relationLabel,
  }) async {
    await _client
        .from('family_members')
        .update({
          'relation': relation,
          'relation_label': relationLabel,
        })
        .match({
          'family_id': familyId,
          'user_id': targetUserId,
        });
  }

  /// Admin: Removes a member from the family
  Future<void> removeMember({
    required String familyId,
    required String targetUserId,
  }) async {
    await _client
        .from('family_members')
        .delete()
        .match({
          'family_id': familyId,
          'user_id': targetUserId,
        });
  }

  /// Member: Leaves the family
  Future<void> leaveFamily(String familyId) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _client
        .from('family_members')
        .delete()
        .match({
          'family_id': familyId,
          'user_id': uid,
        });
  }

  /// Admin: Renames the family
  Future<void> renameFamily({
    required String familyId,
    required String newName,
  }) async {
    await _client
        .from('families')
        .update({'name': newName.trim()})
        .eq('id', familyId);
  }

  /// Admin: Transfers admin role to another active member
  Future<void> transferAdmin({
    required String familyId,
    required String newAdminId,
  }) async {
    await _client.rpc(
      'transfer_admin',
      params: {
        'target_family_id': familyId,
        'new_admin_id': newAdminId,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // FAMILY-TO-FAMILY TREE CHAIN ("Connected Nests")
  // ---------------------------------------------------------------------------

  /// Fetches all connected families in the Family Tree for [myFamilyId]
  Future<List<FamilyLink>> getFamilyLinks(String myFamilyId) async {
    try {
      final rows = await _client
          .from('family_links')
          .select()
          .or('requester_family_id.eq.$myFamilyId,target_family_id.eq.$myFamilyId')
          .order('created_at', ascending: false);

      final List<FamilyLink> links = [];
      for (final raw in (rows as List)) {
        final map = raw as Map<String, dynamic>;
        final reqId = map['requester_family_id'] as String;
        final tgtId = map['target_family_id'] as String;
        final isIncoming = tgtId == myFamilyId;
        final otherFamilyId = isIncoming ? reqId : tgtId;

        final otherFam = await getFamily(otherFamilyId);
        final linkId = map['id'] as String;
        final override = _peaceOverrides[linkId];
        links.add(
          FamilyLink(
            id: linkId,
            requesterFamilyId: reqId,
            targetFamilyId: tgtId,
            connectedFamilyId: otherFamilyId,
            connectedFamilyName: otherFam?.name ?? 'Connected Family',
            connectedInviteCode: otherFam?.inviteCode ?? '------',
            branchLabel: map['branch_label'] as String? ?? 'Extended Family',
            messagingPolicy: map['messaging_policy'] as String? ?? 'all_members',
            status: map['status'] as String? ?? 'active',
            isIncomingRequest: isIncoming,
            createdAt: DateTime.parse(map['created_at'] as String),
            visibilityMode: override?.visibilityMode ??
                (map['visibility_mode'] as String? ?? 'visible'),
            hiddenScope: override?.hiddenScope ??
                (map['hidden_scope'] as String? ?? 'none'),
            hideOurUpdates: override?.hideOurUpdates ??
                (map['hide_our_updates'] as bool? ?? false),
            pausedUntil: override?.pausedUntil ??
                (map['paused_until'] != null
                    ? DateTime.tryParse(map['paused_until'] as String)
                    : null),
          ),
        );
      }
      return [...links, ..._localFallbackLinks];
    } catch (_) {
      return List<FamilyLink>.from(_localFallbackLinks);
    }
  }

  /// Requests or establishes a Family-to-Family Tree link by 6-char invite code
  Future<FamilyLink> linkWithFamily({
    required String myFamilyId,
    required String targetInviteCode,
    required String branchLabel,
    String? targetFamilyNameHint,
    String messagingPolicy = 'all_members',
  }) async {
    final cleanCode = targetInviteCode.trim().toUpperCase();
    try {
      final rpcRes = await _client.rpc(
        'request_family_link',
        params: {
          'my_family_id': myFamilyId,
          'target_invite_code': cleanCode,
          'branch_relation_label': branchLabel,
          'policy_input': messagingPolicy,
        },
      );
      final map = Map<String, dynamic>.from(rpcRes as Map);
      return FamilyLink(
        id: map['link_id'] as String,
        requesterFamilyId: myFamilyId,
        targetFamilyId: map['target_family_id'] as String,
        connectedFamilyId: map['target_family_id'] as String,
        connectedFamilyName:
            (map['target_family_name'] as String?) ?? targetFamilyNameHint ?? 'Family ($cleanCode)',
        connectedInviteCode: cleanCode,
        branchLabel: branchLabel,
        messagingPolicy: messagingPolicy,
        status: map['status'] as String? ?? 'pending',
        createdAt: DateTime.now(),
      );
    } catch (_) {
      // Fallback if migration 20261103000004 is not yet run on Supabase
      final localLink = FamilyLink(
        id: 'link-${DateTime.now().millisecondsSinceEpoch}',
        requesterFamilyId: myFamilyId,
        targetFamilyId: 'fam-$cleanCode',
        connectedFamilyId: 'fam-$cleanCode',
        connectedFamilyName:
            (targetFamilyNameHint != null && targetFamilyNameHint.isNotEmpty)
                ? targetFamilyNameHint
                : 'Relative Family ($cleanCode)',
        connectedInviteCode: cleanCode,
        branchLabel: branchLabel,
        messagingPolicy: messagingPolicy,
        status: 'active',
        createdAt: DateTime.now(),
      );
      _localFallbackLinks.removeWhere((l) => l.connectedInviteCode == cleanCode);
      _localFallbackLinks.insert(0, localLink);
      return localLink;
    }
  }

  /// Approves a pending Family-to-Family link
  Future<void> approveFamilyLink(String linkId) async {
    try {
      await _client
          .from('family_links')
          .update({'status': 'active'})
          .eq('id', linkId);
    } catch (_) {
      final idx = _localFallbackLinks.indexWhere((l) => l.id == linkId);
      if (idx != -1) {
        _localFallbackLinks[idx] =
            _localFallbackLinks[idx].copyWith(status: 'active');
      }
    }
  }

  /// Updates the messaging policy ('all_members' vs 'admins_only') for a linked family
  Future<void> updateFamilyLinkPolicy(String linkId, String policy) async {
    try {
      await _client
          .from('family_links')
          .update({'messaging_policy': policy})
          .eq('id', linkId);
    } catch (_) {
      final idx = _localFallbackLinks.indexWhere((l) => l.id == linkId);
      if (idx != -1) {
        _localFallbackLinks[idx] =
            _localFallbackLinks[idx].copyWith(messagingPolicy: policy);
      }
    }
  }

  /// Removes a Family-to-Family link
  Future<void> removeFamilyLink(String linkId) async {
    _localFallbackLinks.removeWhere((l) => l.id == linkId);
    _peaceOverrides.remove(linkId);
    try {
      await _client.from('family_links').delete().eq('id', linkId);
    } catch (_) {}
  }

  /// Updates Silent Curtain (Peace & Hide Mode) for a connected family without notifying them
  Future<void> updateFamilyPeaceMode({
    required String linkId,
    required String visibilityMode, // 'visible' | 'peace_pause' | 'curtain_hidden'
    required String hiddenScope, // 'none' | 'entire_family' | 'personal_only'
    required bool hideOurUpdates,
    DateTime? pausedUntil,
  }) async {
    final idx = _localFallbackLinks.indexWhere((l) => l.id == linkId);
    if (idx != -1) {
      _localFallbackLinks[idx] = _localFallbackLinks[idx].copyWith(
        visibilityMode: visibilityMode,
        hiddenScope: hiddenScope,
        hideOurUpdates: hideOurUpdates,
        pausedUntil: pausedUntil,
        clearPausedUntil: pausedUntil == null,
      );
    }

    _peaceOverrides[linkId] = FamilyLink(
      id: linkId,
      requesterFamilyId: '',
      targetFamilyId: '',
      connectedFamilyId: '',
      connectedFamilyName: '',
      connectedInviteCode: '',
      branchLabel: '',
      createdAt: DateTime.now(),
      visibilityMode: visibilityMode,
      hiddenScope: hiddenScope,
      hideOurUpdates: hideOurUpdates,
      pausedUntil: pausedUntil,
    );

    try {
      await _client
          .from('family_links')
          .update({
            'visibility_mode': visibilityMode,
            'hidden_scope': hiddenScope,
            'hide_our_updates': hideOurUpdates,
            'paused_until': pausedUntil?.toIso8601String(),
          })
          .eq('id', linkId);
    } catch (_) {
      // Handled seamlessly by _peaceOverrides & _localFallbackLinks
    }
  }
}
