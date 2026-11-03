import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/crypto/media_crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../family/presentation/family_controller.dart';
import '../data/chat_repository.dart';
import '../domain/chat_message_model.dart';

/// Stream of decrypted family group messages from local SQLite Drift database
final familyMessagesProvider = StreamProvider.autoDispose<List<ChatMessage>>((ref) async* {
  final membership = await ref.watch(currentMembershipProvider.future);
  if (membership == null) {
    yield [];
    return;
  }

  final repository = ref.watch(chatRepositoryProvider);
  repository.startRealtimeSync(membership.familyId);

  final db = ref.watch(appDatabaseProvider);
  yield* db.watchFamilyMessages(membership.familyId).map((rows) {
    return rows.map((r) => ChatMessage(
          id: r.id,
          familyId: r.familyId,
          senderId: r.senderId,
          senderName: r.senderName,
          type: MessageType.fromString(r.type),
          audience: MessageAudience.fromString(r.audience),
          plaintext: r.plaintext,
          replyToId: r.replyToId,
          recipientIds: r.recipientIds != null ? r.recipientIds!.split(',') : [],
          isMine: r.isMine,
          createdAt: r.createdAt,
          editedAt: r.editedAt,
          deletedAt: r.deletedAt,
        )).toList();
  });
});

/// Stream of decrypted 1-to-1 direct messages with a specific member
final directMessagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, otherUserId) async* {
  final membership = await ref.watch(currentMembershipProvider.future);
  if (membership == null) {
    yield [];
    return;
  }

  final repository = ref.watch(chatRepositoryProvider);
  repository.startRealtimeSync(membership.familyId);

  final db = ref.watch(appDatabaseProvider);
  yield* db
      .watchDirectMessages(
        familyId: membership.familyId,
        otherUserId: otherUserId,
        myUserId: membership.userId,
      )
      .map((rows) {
        return rows.map((r) => ChatMessage(
              id: r.id,
              familyId: r.familyId,
              senderId: r.senderId,
              senderName: r.senderName,
              type: MessageType.fromString(r.type),
              audience: MessageAudience.fromString(r.audience),
              plaintext: r.plaintext,
              replyToId: r.replyToId,
              recipientIds: r.recipientIds != null ? r.recipientIds!.split(',') : [],
              isMine: r.isMine,
              createdAt: r.createdAt,
              editedAt: r.editedAt,
              deletedAt: r.deletedAt,
            )).toList();
      });
});

/// State of audience selection for outgoing message
class AudienceState {
  final MessageAudience audience;
  final List<String> selectedRecipientIds;

  const AudienceState({
    this.audience = MessageAudience.all,
    this.selectedRecipientIds = const [],
  });

  AudienceState copyWith({
    MessageAudience? audience,
    List<String>? selectedRecipientIds,
  }) {
    return AudienceState(
      audience: audience ?? this.audience,
      selectedRecipientIds: selectedRecipientIds ?? this.selectedRecipientIds,
    );
  }
}

final audienceStateProvider =
    StateNotifierProvider.autoDispose<AudienceNotifier, AudienceState>((ref) {
  return AudienceNotifier();
});

class AudienceNotifier extends StateNotifier<AudienceState> {
  AudienceNotifier() : super(const AudienceState());

  void setEveryone() {
    state = const AudienceState(audience: MessageAudience.all);
  }

  void setSelected(List<String> recipientIds) {
    state = AudienceState(
      audience: MessageAudience.selected,
      selectedRecipientIds: recipientIds,
    );
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, AsyncValue<void>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return ChatController(ref, repository);
});

class ChatController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final ChatRepository _repository;

  ChatController(this._ref, this._repository)
      : super(const AsyncValue.data(null));

  Future<bool> sendMessage({
    required String familyId,
    required String text,
    required MessageAudience audience,
    List<String> selectedRecipientIds = const [],
    String? replyToId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.sendEncryptedMessage(
        familyId: familyId,
        text: text,
        audience: audience,
        selectedRecipientUserIds: selectedRecipientIds,
        replyToId: replyToId,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> sendMediaMessage({
    required String familyId,
    required MessageAudience audience,
    required List<String> selectedRecipientIds,
    required List<int> rawBytes,
    required String fileExtension,
    required MessageType type,
    int? durationMs,
    String? caption,
  }) async {
    state = const AsyncValue.loading();
    try {
      final mediaService = _ref.read(mediaCryptoServiceProvider);
      final encryptedMedia = await mediaService.encryptAndUploadMedia(
        familyId: familyId,
        rawBytes: Uint8List.fromList(rawBytes),
        fileExtension: fileExtension,
        durationMs: durationMs,
      );

      await _repository.sendEncryptedMessage(
        familyId: familyId,
        text: caption ?? (type == MessageType.voice ? 'Voice note' : 'Photo'),
        audience: audience,
        selectedRecipientUserIds: selectedRecipientIds,
        type: type,
        mediaMeta: encryptedMedia.toJson(),
      );

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    await _repository.deleteMessage(messageId);
  }
}
