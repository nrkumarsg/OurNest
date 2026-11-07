import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../data/family_repository.dart';
import '../domain/family_link_model.dart';
import '../domain/family_member_model.dart';
import '../domain/family_model.dart';

/// Provides current user's family membership (if any)
final currentMembershipProvider =
    FutureProvider.autoDispose<FamilyMember?>((ref) async {
  final repository = ref.watch(familyRepositoryProvider);
  return repository.getCurrentUserMembership();
});

/// Provides the active family details
final currentFamilyProvider =
    FutureProvider.autoDispose<Family?>((ref) async {
  final membership = await ref.watch(currentMembershipProvider.future);
  if (membership == null) return null;

  final repository = ref.watch(familyRepositoryProvider);
  return repository.getFamily(membership.familyId);
});

/// Provides list of all members in the current family
final familyMembersProvider =
    FutureProvider.autoDispose<List<FamilyMember>>((ref) async {
  final membership = await ref.watch(currentMembershipProvider.future);
  if (membership == null) return [];

  final repository = ref.watch(familyRepositoryProvider);
  return repository.getFamilyMembers(membership.familyId);
});

/// Provides list of pending member applications (for admins)
final pendingMembersProvider = Provider.autoDispose<List<FamilyMember>>((ref) {
  final membersAsync = ref.watch(familyMembersProvider);
  return membersAsync.maybeWhen(
    data: (members) => members.where((m) => m.isPending).toList(),
    orElse: () => [],
  );
});

/// Provides list of active members
final activeMembersProvider = Provider.autoDispose<List<FamilyMember>>((ref) {
  final membersAsync = ref.watch(familyMembersProvider);
  return membersAsync.maybeWhen(
    data: (members) => members.where((m) => m.isActive).toList(),
    orElse: () => [],
  );
});

/// Provides list of connected relative families in the Family Tree
final familyLinksProvider =
    FutureProvider.autoDispose<List<FamilyLink>>((ref) async {
  final membership = await ref.watch(currentMembershipProvider.future);
  if (membership == null) return [];

  final repository = ref.watch(familyRepositoryProvider);
  return repository.getFamilyLinks(membership.familyId);
});

/// Controller for Family mutations
final familyControllerProvider =
    StateNotifierProvider<FamilyController, AsyncValue<void>>((ref) {
  final repository = ref.watch(familyRepositoryProvider);
  return FamilyController(ref, repository);
});

class FamilyController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final FamilyRepository _repository;

  FamilyController(this._ref, this._repository)
      : super(const AsyncValue.data(null));

  void _invalidateAll() {
    _ref.invalidate(currentMembershipProvider);
    _ref.invalidate(currentFamilyProvider);
    _ref.invalidate(familyMembersProvider);
    _ref.invalidate(familyLinksProvider);
  }

  Future<bool> createFamily({
    required String name,
    required String adminRelation,
    String? adminRelationLabel,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createFamily(
        name: name,
        adminRelation: adminRelation,
        adminRelationLabel: adminRelationLabel,
      );
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> joinFamily({
    required String inviteCode,
    required String applicantRelation,
    String? applicantRelationLabel,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.joinFamily(
        inviteCode: inviteCode,
        applicantRelation: applicantRelation,
        applicantRelationLabel: applicantRelationLabel,
      );
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> approveMember({
    required String familyId,
    required String targetUserId,
    String? assignedRelation,
    String? assignedLabel,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.approveMember(
        familyId: familyId,
        targetUserId: targetUserId,
        assignedRelation: assignedRelation,
        assignedLabel: assignedLabel,
      );
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateMemberRelation({
    required String familyId,
    required String targetUserId,
    required String relation,
    String? relationLabel,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateMemberRelation(
        familyId: familyId,
        targetUserId: targetUserId,
        relation: relation,
        relationLabel: relationLabel,
      );
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> removeMember({
    required String familyId,
    required String targetUserId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.removeMember(
        familyId: familyId,
        targetUserId: targetUserId,
      );
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> leaveFamily(String familyId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.leaveFamily(familyId);
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Admin: issues a new invite code (F20). Returns the new code, or null.
  Future<String?> regenerateInviteCode(String familyId) async {
    state = const AsyncValue.loading();
    try {
      final code = await _repository.regenerateInviteCode(familyId);
      state = const AsyncValue.data(null);
      _invalidateAll();
      return code;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> renameFamily({
    required String familyId,
    required String newName,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.renameFamily(familyId: familyId, newName: newName);
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> transferAdmin({
    required String familyId,
    required String newAdminId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.transferAdmin(
        familyId: familyId,
        newAdminId: newAdminId,
      );
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> setMemberAdminRole({
    required String familyId,
    required String targetUserId,
    required bool makeAdmin,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.setMemberAdminRole(
        familyId: familyId,
        targetUserId: targetUserId,
        makeAdmin: makeAdmin,
      );
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> linkWithFamily({
    required String myFamilyId,
    required String targetInviteCode,
    required String branchLabel,
    String? targetFamilyNameHint,
    String messagingPolicy = 'all_members',
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.linkWithFamily(
        myFamilyId: myFamilyId,
        targetInviteCode: targetInviteCode,
        branchLabel: branchLabel,
        targetFamilyNameHint: targetFamilyNameHint,
        messagingPolicy: messagingPolicy,
      );
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> approveFamilyLink(String linkId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.approveFamilyLink(linkId);
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateFamilyLinkPolicy(String linkId, String policy) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateFamilyLinkPolicy(linkId, policy);
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> removeFamilyLink(String linkId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.removeFamilyLink(linkId);
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateFamilyPeaceMode({
    required String linkId,
    required String visibilityMode,
    required String hiddenScope,
    required bool hideOurUpdates,
    DateTime? pausedUntil,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateFamilyPeaceMode(
        linkId: linkId,
        visibilityMode: visibilityMode,
        hiddenScope: hiddenScope,
        hideOurUpdates: hideOurUpdates,
        pausedUntil: pausedUntil,
      );
      state = const AsyncValue.data(null);
      _invalidateAll();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
