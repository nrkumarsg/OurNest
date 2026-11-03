import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_repository.dart';
import '../domain/profile_model.dart';

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.user == null) return null;

  final repository = ref.watch(profileRepositoryProvider);
  return repository.getProfile(authState.user!.id);
});

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<Profile?>>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return ProfileController(ref, repository);
});

class ProfileController extends StateNotifier<AsyncValue<Profile?>> {
  final Ref _ref;
  final ProfileRepository _repository;

  ProfileController(this._ref, this._repository)
      : super(const AsyncValue.loading()) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authState = _ref.read(authControllerProvider);
    if (authState.user == null) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final profile = await _repository.getProfile(authState.user!.id);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> saveProfile({
    required String displayName,
    String? phone,
    String? whatsappNumber,
    String? avatarUrl,
    String? sex,
    DateTime? dateOfBirth,
    String? bloodGroup,
    String? education,
    String? occupation,
    String? workingPlace,
    String? workingDetails,
    String? livingPlace,
    String? homeAddress,
    String? city,
    String? statusText,
    String? bioDescription,
  }) async {
    final authState = _ref.read(authControllerProvider);
    final activeUserId =
        authState.user?.id ?? Supabase.instance.client.auth.currentUser?.id;
    if (activeUserId == null) return false;

    state = const AsyncValue.loading();
    try {
      String? clean(String? val) =>
          (val != null && val.trim().isNotEmpty) ? val.trim() : null;

      final newProfile = Profile(
        id: activeUserId,
        displayName: displayName.trim(),
        phone: clean(phone) ?? authState.phoneNumber ?? authState.user?.phone,
        whatsappNumber: clean(whatsappNumber),
        avatarUrl: avatarUrl,
        sex: clean(sex),
        dateOfBirth: dateOfBirth,
        bloodGroup: clean(bloodGroup),
        education: clean(education),
        occupation: clean(occupation),
        workingPlace: clean(workingPlace),
        workingDetails: clean(workingDetails),
        livingPlace: clean(livingPlace),
        homeAddress: clean(homeAddress),
        city: clean(city),
        statusText: clean(statusText) ?? 'Available for family ❤️',
        bioDescription: clean(bioDescription),
        createdAt: DateTime.now(),
      );

      final saved = await _repository.upsertProfile(newProfile);
      state = AsyncValue.data(saved);
      _ref.invalidate(currentProfileProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
