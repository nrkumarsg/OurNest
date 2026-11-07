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
    final map = Map<String, dynamic>.from(response as Map);
    // The server returns {error: ...} for a wrong code so the attempt limit
    // can count it (F20).
    final error = map['error'];
    if (error is String && error.isNotEmpty) throw StateError(error);
    return map;
  }

  /// Admin: replaces the family's invite code; old codes / QR stop working.
  Future<String> regenerateInviteCode(String familyId) async {
    final res = await _client.rpc(
      'regenerate_invite_code',
      params: {'target_family_id': familyId},
    );
    return res as String;
  }

  /// Fetches the user's current family membership (including pending).
  ///
  /// A user can end up with more than one membership row (the join RPC allows
  /// it). `.maybeSingle()` used to throw in that case and locked the user out
  /// (audit F13). Until the owner decides whether multiple families are
  /// allowed (Q1), one is picked deterministically: see [pickPrimaryMembership].
  Future<FamilyMember?> getCurrentUserMembership() async {
    final uid = currentUserId;
    if (uid == null) return null;

    final response = await _client
        .from('family_members')
        .select('*, profiles(*)')
        .eq('user_id', uid)
        .order('created_at', ascending: true);

    final memberships = (response as List)
        .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
        .toList();
    return pickPrimaryMembership(memberships);
  }

  /// Prefers an active membership over a pending one, then the oldest.
  static FamilyMember? pickPrimaryMembership(List<FamilyMember> memberships) {
    if (memberships.isEmpty) return null;
    final sorted = [...memberships]
      ..sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.createdAt.compareTo(b.createdAt);
      });
    return sorted.first;
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
    final rows = await _client
        .from('family_members')
        .delete()
        .match({
          'family_id': familyId,
          'user_id': targetUserId,
        })
        .select('user_id');
    expectChanged(rows, 'Only the family admin can remove members.');
  }

  /// Member: Leaves the family
  Future<void> leaveFamily(String familyId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final rows = await _client
        .from('family_members')
        .delete()
        .match({
          'family_id': familyId,
          'user_id': uid,
        })
        .select('user_id');
    expectChanged(rows, 'You are not a member of this family.');
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

  /// Admin: Grants or revokes Shared Admin (Co-Admin) rights for another member
  /// while keeping the current Admin's own Admin role intact.
  Future<void> setMemberAdminRole({
    required String familyId,
    required String targetUserId,
    required bool makeAdmin,
  }) async {
    final rows = await _client
        .from('family_members')
        .update({'role': makeAdmin ? 'admin' : 'member'})
        .match({
          'family_id': familyId,
          'user_id': targetUserId,
        })
        .select('user_id');
    expectChanged(rows, 'Only an Admin can grant or remove Shared Admin rights.');
  }

  // ---------------------------------------------------------------------------
  // FAMILY-TO-FAMILY TREE CHAIN ("Connected Nests")
  //
  // Audit F07 / U19: errors are no longer hidden behind invented "active"
  // links or in-memory overrides. Every call either saves on the server or
  // throws, so the screen can tell the user the truth.
  // ---------------------------------------------------------------------------

  /// Fetches all connected families in the Family Tree for [myFamilyId]
  Future<List<FamilyLink>> getFamilyLinks(String myFamilyId) async {
    final rows = await _client
        .from('family_links')
        .select()
        .or('requester_family_id.eq.$myFamilyId,target_family_id.eq.$myFamilyId')
        .order('created_at', ascending: false);

    // One call for all linked family names (F32: RLS hides other families'
    // rows, so getFamily() always returned null; this also removes the N+1).
    final names = await _linkedFamilyNames(myFamilyId);

    return (rows as List).map((raw) {
      final map = raw as Map<String, dynamic>;
      final reqId = map['requester_family_id'] as String;
      final tgtId = map['target_family_id'] as String;
      final isIncoming = tgtId == myFamilyId;
      final linkId = map['id'] as String;
      return FamilyLink(
        id: linkId,
        requesterFamilyId: reqId,
        targetFamilyId: tgtId,
        connectedFamilyId: isIncoming ? reqId : tgtId,
        connectedFamilyName: names[linkId] ?? 'Connected Family',
        // The other family's invite code lets people join it, so it's private
        // to them and not shown here.
        connectedInviteCode: '',
        branchLabel: map['branch_label'] as String? ?? 'Extended Family',
        messagingPolicy: map['messaging_policy'] as String? ?? 'all_members',
        status: map['status'] as String? ?? 'pending',
        isIncomingRequest: isIncoming,
        createdAt: DateTime.parse(map['created_at'] as String),
        visibilityMode: map['visibility_mode'] as String? ?? 'visible',
        hiddenScope: map['hidden_scope'] as String? ?? 'none',
        hideOurUpdates: map['hide_our_updates'] as bool? ?? false,
        pausedUntil: map['paused_until'] != null
            ? DateTime.tryParse(map['paused_until'] as String)
            : null,
      );
    }).toList();
  }

  Future<Map<String, String>> _linkedFamilyNames(String myFamilyId) async {
    try {
      final res = await _client.rpc(
        'get_linked_family_names',
        params: {'my_family_id': myFamilyId},
      );
      return {
        for (final r in (res as List))
          r['link_id'] as String: r['family_name'] as String,
      };
    } on PostgrestException catch (e) {
      // Migration 20261105000008 not applied yet: keep the placeholder name.
      if (e.code == 'PGRST202') return {};
      rethrow;
    }
  }

  /// Sends a link request to another family using its 6-char invite code.
  /// The link stays 'pending' until the other family's admin approves it.
  Future<FamilyLink> linkWithFamily({
    required String myFamilyId,
    required String targetInviteCode,
    required String branchLabel,
    String? targetFamilyNameHint,
    String messagingPolicy = 'all_members',
  }) async {
    final cleanCode = targetInviteCode.trim().toUpperCase();
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
      connectedFamilyName: (map['target_family_name'] as String?) ??
          targetFamilyNameHint ??
          'Connected Family',
      connectedInviteCode: '',
      branchLabel: branchLabel,
      messagingPolicy: messagingPolicy,
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.now(),
    );
  }

  /// Approves a pending Family-to-Family link (the database only allows the
  /// invited family's admin).
  Future<void> approveFamilyLink(String linkId) async {
    final rows = await _client
        .from('family_links')
        .update({'status': 'active'})
        .eq('id', linkId)
        .select('id');
    expectChanged(rows, 'You can only approve requests sent to your family.');
  }

  /// Updates the messaging policy ('all_members' vs 'admins_only') for a linked family
  Future<void> updateFamilyLinkPolicy(String linkId, String policy) async {
    final rows = await _client
        .from('family_links')
        .update({'messaging_policy': policy})
        .eq('id', linkId)
        .select('id');
    expectChanged(rows, 'Only a family admin can change this.');
  }

  /// Removes a Family-to-Family link
  Future<void> removeFamilyLink(String linkId) async {
    final rows =
        await _client.from('family_links').delete().eq('id', linkId).select('id');
    expectChanged(rows, 'Only a family admin can remove this connection.');
  }

  /// Updates Silent Curtain (Peace & Hide Mode) for a connected family
  Future<void> updateFamilyPeaceMode({
    required String linkId,
    required String visibilityMode, // 'visible' | 'peace_pause' | 'curtain_hidden'
    required String hiddenScope, // 'none' | 'entire_family' | 'personal_only'
    required bool hideOurUpdates,
    DateTime? pausedUntil,
  }) async {
    final rows = await _client
        .from('family_links')
        .update({
          'visibility_mode': visibilityMode,
          'hidden_scope': hiddenScope,
          'hide_our_updates': hideOurUpdates,
          'paused_until': pausedUntil?.toUtc().toIso8601String(),
        })
        .eq('id', linkId)
        .select('id');
    expectChanged(rows, 'Only a family admin can change this.');
  }

  /// Row Level Security silently matches 0 rows when you're not allowed,
  /// which used to look like success. Treat "nothing changed" as an error.
  static void expectChanged(List<dynamic> rows, String notAllowedMessage) {
    if (rows.isEmpty) throw StateError(notAllowedMessage);
  }
}
