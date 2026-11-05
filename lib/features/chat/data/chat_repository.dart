import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/crypto/device_key_manager.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/chat_message_model.dart';
import '../domain/message_payload.dart';

/// Live set of user IDs currently online in the family Realtime channel
final onlineUserIdsProvider = StateProvider<Set<String>>((ref) => <String>{});

/// Message IDs that have been delivered to at least one recipient device (Double Tick ✓✓)
final deliveredMessageIdsProvider =
    StateProvider<Set<String>>((ref) => <String>{});

/// Message IDs that have been read/opened by a recipient (Highlighted Double Tick ✓✓)
final readMessageIdsProvider = StateProvider<Set<String>>((ref) => <String>{});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final crypto = ref.watch(cryptoServiceProvider);
  final keyManager = ref.watch(deviceKeyManagerProvider);
  final db = ref.watch(appDatabaseProvider);
  return ChatRepository(ref, client, crypto, keyManager, db);
});

class ChatRepository {
  final Ref _ref;
  final SupabaseClient _client;
  final CryptoService _crypto;
  final DeviceKeyManager _keyManager;
  final AppDatabase _db;
  RealtimeChannel? _subscription;

  ChatRepository(
      this._ref, this._client, this._crypto, this._keyManager, this._db);

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Sends an end-to-end encrypted message to either 'all' or 'selected' recipients
  Future<void> sendEncryptedMessage({
    required String familyId,
    required String text,
    required MessageAudience audience,
    List<String> selectedRecipientUserIds = const [],
    MessageType type = MessageType.text,
    String? replyToId,
    Map<String, dynamic>? mediaMeta,
    Map<String, dynamic>? alarmMeta,
  }) async {
    final senderId = currentUserId;
    if (senderId == null) throw StateError('User not logged in');

    await _keyManager.ensureDeviceKeys();
    final senderDeviceId = _keyManager.currentDeviceId;
    if (senderDeviceId == null) throw StateError('Device not registered');

    // 1. Prepare JSON payload
    final payload = MessagePayload(
      text: text,
      replyToId: replyToId,
      mediaMeta: mediaMeta,
      alarmMeta: alarmMeta,
    );
    final jsonStr = payload.toEncodedJson();

    // 2. Encrypt payload with random symmetric key (XChaCha20-Poly1305)
    final encrypted = _crypto.encryptMessagePayload(jsonPlaintext: jsonStr);

    // 3. Determine recipient user IDs
    List<String> targetUserIds = [];
    if (audience == MessageAudience.all) {
      final membersRes = await _client
          .from('family_members')
          .select('user_id')
          .eq('family_id', familyId)
          .eq('status', 'active');
      targetUserIds = (membersRes as List).map((e) => e['user_id'] as String).toList();
    } else {
      targetUserIds = List<String>.from(selectedRecipientUserIds);
      if (!targetUserIds.contains(senderId)) {
        targetUserIds.add(senderId); // Always include sender
      }
    }

    // 4. Fetch public keys of all recipient devices
    final devicesRes = await _client
        .from('user_devices')
        .select('id, user_id, public_key')
        .inFilter('user_id', targetUserIds)
        .filter('revoked_at', 'is', null);

    final recipientDevices = devicesRes as List;

    // 5. Insert messages row
    final insertMsg = await _client
        .from('messages')
        .insert({
          'family_id': familyId,
          'sender_id': senderId,
          'sender_device_id': senderDeviceId,
          'type': type.toDbString(),
          'audience': audience == MessageAudience.all ? 'all' : 'selected',
          'ciphertext': encrypted.ciphertextBase64,
          'nonce': encrypted.nonceBase64,
        })
        .select('id, created_at')
        .single();

    final messageId = insertMsg['id'] as String;
    final createdAt = DateTime.parse(insertMsg['created_at'] as String);

    // 6. Insert message_recipients rows
    final recipientRows = targetUserIds.map((uid) => {
          'message_id': messageId,
          'user_id': uid,
        }).toList();
    await _client.from('message_recipients').insert(recipientRows);

    // 7. Lock message key for each recipient device with crypto_box_seal
    final keyRows = recipientDevices.map((dev) {
      final devId = dev['id'] as String;
      final pubKeyB64 = dev['public_key'] as String;
      final lockedKey = _crypto.sealMessageKey(
        messageKeyBytes: encrypted.rawMessageKey,
        recipientPublicKeyBase64: pubKeyB64,
      );
      return {
        'message_id': messageId,
        'recipient_device_id': devId,
        'locked_key': lockedKey,
      };
    }).toList();

    if (keyRows.isNotEmpty) {
      await _client.from('message_keys').insert(keyRows);
    }

    // 8. Immediately store decrypted message in local Drift database for zero latency
    await _db.insertOrUpdateMessage(
      LocalMessagesCompanion(
        id: drift.Value(messageId),
        familyId: drift.Value(familyId),
        senderId: drift.Value(senderId),
        type: drift.Value(type.toDbString()),
        audience: drift.Value(audience == MessageAudience.all ? 'all' : 'selected'),
        plaintext: drift.Value(jsonStr),
        replyToId: drift.Value(replyToId),
        recipientIds: drift.Value(targetUserIds.join(',')),
        isMine: const drift.Value(true),
        createdAt: drift.Value(createdAt),
      ),
    );
  }

  /// Listens to Realtime messages, tracks Online/Offline Presence, and handles Single/Double/Read Ticks
  void startRealtimeSync(String familyId) {
    _subscription?.unsubscribe();

    final channel = _client.channel('family_chat_$familyId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'family_id',
            value: familyId,
          ),
          callback: (payload) async {
            await _handleRealtimeMessage(payload.newRecord);
          },
        )
        .onPresenceSync((_) {
          try {
            final state = channel.presenceState();
            final onlineIds = <String>{};
            for (final singleState in state) {
              for (final presence in singleState.presences) {
                final uid = presence.payload['user_id']?.toString();
                if (uid != null && uid.isNotEmpty) {
                  onlineIds.add(uid);
                }
              }
            }
            if (currentUserId != null) {
              onlineIds.add(currentUserId!);
            }
            _ref.read(onlineUserIdsProvider.notifier).state = onlineIds;
          } catch (_) {}
        })
        .onBroadcast(
          event: 'delivery_ack',
          callback: (payload) {
            final msgId = payload['message_id']?.toString();
            if (msgId != null && msgId.isNotEmpty) {
              final current =
                  Set<String>.from(_ref.read(deliveredMessageIdsProvider));
              current.add(msgId);
              _ref.read(deliveredMessageIdsProvider.notifier).state = current;
            }
          },
        )
        .onBroadcast(
          event: 'read_ack',
          callback: (payload) {
            final msgId = payload['message_id']?.toString();
            if (msgId != null && msgId.isNotEmpty) {
              final currentDeliv =
                  Set<String>.from(_ref.read(deliveredMessageIdsProvider));
              currentDeliv.add(msgId);
              _ref.read(deliveredMessageIdsProvider.notifier).state =
                  currentDeliv;

              final currentRead =
                  Set<String>.from(_ref.read(readMessageIdsProvider));
              currentRead.add(msgId);
              _ref.read(readMessageIdsProvider.notifier).state = currentRead;
            }
          },
        )
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed &&
              currentUserId != null) {
            try {
              await channel.track({
                'user_id': currentUserId,
                'online_at': DateTime.now().toIso8601String(),
              });
            } catch (_) {}
          }
        });

    _subscription = channel;
  }

  /// Sends a read receipt broadcast when the user views incoming messages
  Future<void> markMessagesAsRead(List<String> messageIds) async {
    final channel = _subscription;
    if (channel == null) return;
    for (final msgId in messageIds) {
      try {
        await channel.sendBroadcastMessage(
          event: 'read_ack',
          payload: {
            'message_id': msgId,
            'reader_id': currentUserId,
          },
        );
      } catch (_) {}
    }
  }

  Future<void> _handleRealtimeMessage(Map<String, dynamic> msgRecord) async {
    final messageId = msgRecord['id'] as String?;
    if (messageId == null) return;

    final senderId = msgRecord['sender_id'] as String;
    if (senderId == currentUserId) return; // Sender already cached it locally

    // Check if soft deleted
    if (msgRecord['deleted_at'] != null) {
      await _db.markDeleted(messageId);
      return;
    }

    await _keyManager.ensureDeviceKeys();
    final myDeviceId = _keyManager.currentDeviceId;
    final myPubKey = _keyManager.currentPublicKey;
    final myPrivKey = _keyManager.currentSecretKey;

    if (myDeviceId == null || myPubKey == null || myPrivKey == null) return;

    // Fetch sealed message key for my device
    final keyRow = await _client
        .from('message_keys')
        .select('locked_key')
        .eq('message_id', messageId)
        .eq('recipient_device_id', myDeviceId)
        .maybeSingle();

    if (keyRow == null) return; // Not a recipient of this message

    final lockedKeyB64 = keyRow['locked_key'] as String;

    try {
      // 1. Unseal message key
      final unsealedKeyBytes = _crypto.openSealedMessageKey(
        lockedKeyBase64: lockedKeyB64,
        devicePublicKey: myPubKey,
        deviceSecretKey: myPrivKey,
      );

      // 2. Decrypt ciphertext with XChaCha20-Poly1305
      final decryptedJson = _crypto.decryptMessagePayload(
        ciphertextBase64: msgRecord['ciphertext'] as String,
        nonceBase64: msgRecord['nonce'] as String,
        messageKeyBytes: unsealedKeyBytes,
      );

      // 3. Store decrypted message in local database
      await _db.insertOrUpdateMessage(
        LocalMessagesCompanion(
          id: drift.Value(messageId),
          familyId: drift.Value(msgRecord['family_id'] as String),
          senderId: drift.Value(senderId),
          type: drift.Value(msgRecord['type'] as String),
          audience: drift.Value(msgRecord['audience'] as String),
          plaintext: drift.Value(decryptedJson),
          isMine: const drift.Value(false),
          createdAt: drift.Value(DateTime.parse(msgRecord['created_at'] as String)),
          editedAt: msgRecord['edited_at'] != null
              ? drift.Value(DateTime.parse(msgRecord['edited_at'] as String))
              : const drift.Value.absent(),
        ),
      );

      // 4. Broadcast immediate Delivery ACK (Double Tick ✓✓) to sender
      try {
        await _subscription?.sendBroadcastMessage(
          event: 'delivery_ack',
          payload: {
            'message_id': messageId,
            'recipient_id': currentUserId,
          },
        );
      } catch (_) {}
    } catch (_) {
      // Message could not be decrypted (e.g. wrong key or corrupted)
    }
  }

  /// Deletes a message ("delete for everyone" tombstone)
  Future<void> deleteMessage(String messageId) async {
    await _client.from('messages').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'ciphertext': 'tombstone',
      'nonce': 'tombstone',
    }).eq('id', messageId);

    await _db.markDeleted(messageId);
  }

  void dispose() {
    _subscription?.unsubscribe();
    _subscription = null;
  }

  /// Stops realtime sync and forgets in-memory presence / receipt state.
  void resetForSignOut() {
    dispose();
    _ref.read(onlineUserIdsProvider.notifier).state = <String>{};
    _ref.read(deliveredMessageIdsProvider.notifier).state = <String>{};
    _ref.read(readMessageIdsProvider.notifier).state = <String>{};
  }
}
