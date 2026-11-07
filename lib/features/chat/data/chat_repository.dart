import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/crypto/device_key_manager.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/notifications/notification_service.dart';
import '../../alarm/data/alarm_coordinator.dart';
import '../domain/chat_message_model.dart';
import '../domain/message_payload.dart';

/// Live set of user IDs currently online in the family Realtime channel
final onlineUserIdsProvider = StateProvider<Set<String>>((ref) => <String>{});

/// Last seen timestamps by user ID (updated from Realtime Presence & message activity)
final lastSeenByUserProvider =
    StateProvider<Map<String, DateTime>>((ref) => <String, DateTime>{});

/// Unread message counts keyed by threadId ('family' or direct userId)
final unreadCountByThreadProvider =
    StateProvider<Map<String, int>>((ref) => <String, int>{});

/// Total unread messages across all threads (used for Android launcher badge)
final totalUnreadCountProvider = Provider<int>((ref) {
  final map = ref.watch(unreadCountByThreadProvider);
  return map.values.fold(0, (sum, v) => sum + v);
});

/// Currently open chat thread ('family', userId, or null when on Home/other screen)
final activeOpenThreadProvider = StateProvider<String?>((ref) => null);

/// Formats a friendly Last Seen string for Chat & Member screens
String formatLastSeen(DateTime? lastSeen, {required bool isOnline}) {
  if (isOnline) return '🟢 Online now';
  if (lastSeen == null) return '⚪ Offline';
  final local = lastSeen.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inSeconds < 60) {
    return '🕒 Last seen just now';
  } else if (diff.inMinutes < 60) {
    return '🕒 Last seen ${diff.inMinutes}m ago';
  }
  final today = DateTime(now.year, now.month, now.day);
  final seenDay = DateTime(local.year, local.month, local.day);
  final timeStr = DateFormat('h:mm a').format(local);
  if (seenDay == today) {
    return '🕒 Last seen today at $timeStr';
  } else if (today.difference(seenDay).inDays == 1) {
    return '🕒 Last seen yesterday at $timeStr';
  } else {
    return '🕒 Last seen ${DateFormat('d MMM, h:mm a').format(local)}';
  }
}

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
  /// How far back the catch-up sync re-checks, to cover small clock
  /// differences between devices and the server. Duplicates are ignored.
  static const syncOverlap = Duration(minutes: 2);

  /// When nothing is stored locally (new device, web reload, after sign-out)
  /// we restore this many of the most recent messages.
  static const initialHistoryLimit = 300;

  static const _pageSize = 200;
  static const _maxPagesPerSync = 10;

  final Ref _ref;
  final SupabaseClient _client;
  final CryptoService _crypto;
  final DeviceKeyManager _keyManager;
  final AppDatabase _db;
  RealtimeChannel? _subscription;
  String? _subscribedFamilyId;
  Future<int>? _runningSync;
  final Set<String> _readAckSent = <String>{};

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
    String? replyToMessageId,
    Map<String, dynamic>? mediaMeta,
    Map<String, dynamic>? alarmMeta,
  }) async {
    final senderId = currentUserId;
    if (senderId == null) throw StateError('User not logged in');

    await _keyManager.ensureDeviceKeys();
    final senderDeviceId = _keyManager.currentDeviceId;
    if (senderDeviceId == null) throw StateError('Device not registered');

    // 1. Determine recipient user IDs (always including the sender, no duplicates)
    final List<String> targetUserIds;
    if (audience == MessageAudience.all) {
      final membersRes = await _client
          .from('family_members')
          .select('user_id')
          .eq('family_id', familyId)
          .eq('status', 'active');
      targetUserIds = {
        senderId,
        ...(membersRes as List).map((e) => e['user_id'] as String),
      }.toList();
    } else {
      targetUserIds = {senderId, ...selectedRecipientUserIds}.toList();
      if (targetUserIds.length < 2) {
        throw StateError('Choose at least one family member to send to.');
      }
    }

    // 2. Prepare JSON payload (recipient list travels encrypted, see F22)
    final payload = MessagePayload(
      text: text,
      replyToId: replyToId,
      replyToMessageId: replyToMessageId,
      mediaMeta: mediaMeta,
      alarmMeta: alarmMeta,
      recipientIds: targetUserIds,
    );
    final jsonStr = payload.toEncodedJson();

    // 3. Encrypt payload with random symmetric key (XChaCha20-Poly1305)
    final encrypted = _crypto.encryptMessagePayload(jsonPlaintext: jsonStr);

    // 4. Fetch public keys of all recipient devices and seal the message key
    final devicesRes = await _client
        .from('user_devices')
        .select('id, user_id, public_key')
        .inFilter('user_id', targetUserIds)
        .filter('revoked_at', 'is', null);

    final keyRows = (devicesRes as List).map((dev) {
      return {
        'device_id': dev['id'] as String,
        'locked_key': _crypto.sealMessageKey(
          messageKeyBytes: encrypted.rawMessageKey,
          recipientPublicKeyBase64: dev['public_key'] as String,
        ),
      };
    }).toList();

    final audienceStr = audience == MessageAudience.all ? 'all' : 'selected';

    // 5. Store message + recipients + keys in ONE transaction (F03)
    final inserted = await _insertMessageAtomically(
      familyId: familyId,
      senderId: senderId,
      senderDeviceId: senderDeviceId,
      type: type.toDbString(),
      audience: audienceStr,
      ciphertext: encrypted.ciphertextBase64,
      nonce: encrypted.nonceBase64,
      recipientIds: targetUserIds,
      keyRows: keyRows,
    );

    // 6. Store decrypted message locally for zero latency
    await _db.insertOrUpdateMessage(
      LocalMessagesCompanion(
        id: drift.Value(inserted.id),
        familyId: drift.Value(familyId),
        senderId: drift.Value(senderId),
        type: drift.Value(type.toDbString()),
        audience: drift.Value(audienceStr),
        plaintext: drift.Value(jsonStr),
        replyToId: drift.Value(replyToId),
        recipientIds: drift.Value(targetUserIds.join(',')),
        isMine: const drift.Value(true),
        createdAt: drift.Value(inserted.createdAt),
      ),
    );
  }

  Future<({String id, DateTime createdAt})> _insertMessageAtomically({
    required String familyId,
    required String senderId,
    required String senderDeviceId,
    required String type,
    required String audience,
    required String ciphertext,
    required String nonce,
    required List<String> recipientIds,
    required List<Map<String, String>> keyRows,
  }) async {
    try {
      final res = await _client.rpc('send_message', params: {
        'p_family_id': familyId,
        'p_sender_device_id': senderDeviceId,
        'p_type': type,
        'p_audience': audience,
        'p_ciphertext': ciphertext,
        'p_nonce': nonce,
        'p_recipient_ids': recipientIds,
        'p_keys': keyRows,
      });
      final map = Map<String, dynamic>.from(res as Map);
      return (
        id: map['id'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
    } on PostgrestException catch (e) {
      // Only fall back when the server doesn't have the RPC yet (migration
      // 20261105000006 not applied). Any other error is real and must surface.
      if (e.code != 'PGRST202') rethrow;
      debugPrint('send_message RPC missing – using legacy 3-step insert');
    }

    final insertMsg = await _client
        .from('messages')
        .insert({
          'family_id': familyId,
          'sender_id': senderId,
          'sender_device_id': senderDeviceId,
          'type': type,
          'audience': audience,
          'ciphertext': ciphertext,
          'nonce': nonce,
        })
        .select('id, created_at')
        .single();
    final messageId = insertMsg['id'] as String;

    await _client.from('message_recipients').insert(recipientIds
        .map((uid) => {'message_id': messageId, 'user_id': uid})
        .toList());
    if (keyRows.isNotEmpty) {
      await _client.from('message_keys').insert(keyRows
          .map((k) => {
                'message_id': messageId,
                'recipient_device_id': k['device_id'],
                'locked_key': k['locked_key'],
              })
          .toList());
    }
    return (
      id: messageId,
      createdAt: DateTime.parse(insertMsg['created_at'] as String),
    );
  }

  /// Listens to Realtime messages, tracks Online/Offline Presence, and handles
  /// Single/Double/Read Ticks. Every (re)connect also runs a catch-up sync so
  /// messages sent while this device was offline are fetched (F02).
  ///
  /// The channel is PRIVATE (F21): the server only lets active members of
  /// this family join (policy in migration 20261105000009). If the server
  /// isn't set up for private channels yet, it falls back to a public channel
  /// once, so chat keeps working during the rollout.
  void startRealtimeSync(String familyId, {bool private = true}) {
    if (_subscription != null && _subscribedFamilyId == familyId) {
      // Already listening (e.g. user opened another thread): just catch up.
      unawaited(_safeSync(familyId));
      return;
    }
    _subscription?.unsubscribe();
    _subscribedFamilyId = familyId;

    final channel = _client.channel(
      'family_chat_$familyId',
      opts: RealtimeChannelConfig(private: private),
    );

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
            try {
              await _handleRealtimeMessage(payload.newRecord);
            } catch (e) {
              debugPrint('Realtime message handling failed: $e');
            }
          },
        )
        .onPresenceSync((_) {
          try {
            final state = channel.presenceState();
            final prevOnline = _ref.read(onlineUserIdsProvider);
            final onlineIds = <String>{};
            final nextLastSeen = Map<String, DateTime>.from(
              _ref.read(lastSeenByUserProvider),
            );
            final now = DateTime.now();

            for (final singleState in state) {
              for (final presence in singleState.presences) {
                final uid = presence.payload['user_id']?.toString();
                if (uid != null && uid.isNotEmpty) {
                  onlineIds.add(uid);
                  final onlineAtStr = presence.payload['online_at']?.toString();
                  final parsed = onlineAtStr != null
                      ? DateTime.tryParse(onlineAtStr)
                      : null;
                  nextLastSeen[uid] = parsed ?? now;
                }
              }
            }
            // Anyone who was online and just disconnected gets their lastSeen stamped to now
            for (final prevUid in prevOnline) {
              if (!onlineIds.contains(prevUid)) {
                nextLastSeen[prevUid] = now;
              }
            }
            if (currentUserId != null) {
              onlineIds.add(currentUserId!);
              nextLastSeen[currentUserId!] = now;
            }
            _ref.read(onlineUserIdsProvider.notifier).state = onlineIds;
            _ref.read(lastSeenByUserProvider.notifier).state = nextLastSeen;
          } catch (_) {}
        })
        .onBroadcast(
          event: 'delivery_ack',
          callback: (payload) {
            final ids = ackMessageIds(payload);
            if (ids.isEmpty) return;
            _ref.read(deliveredMessageIdsProvider.notifier).state = {
              ..._ref.read(deliveredMessageIdsProvider),
              ...ids,
            };
          },
        )
        .onBroadcast(
          event: 'read_ack',
          callback: (payload) {
            final ids = ackMessageIds(payload);
            if (ids.isEmpty) return;
            _ref.read(deliveredMessageIdsProvider.notifier).state = {
              ..._ref.read(deliveredMessageIdsProvider),
              ...ids,
            };
            _ref.read(readMessageIdsProvider.notifier).state = {
              ..._ref.read(readMessageIdsProvider),
              ...ids,
            };
          },
        )
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.channelError &&
              private &&
              identical(_subscription, channel)) {
            debugPrint('Private realtime channel refused ($error); '
                'falling back to public channel. Apply migration 20261105000009.');
            channel.unsubscribe();
            _subscription = null;
            startRealtimeSync(familyId, private: false);
            return;
          }
          if (status == RealtimeSubscribeStatus.subscribed &&
              currentUserId != null) {
            try {
              await channel.track({
                'user_id': currentUserId,
                'online_at': DateTime.now().toIso8601String(),
              });
            } catch (_) {}
            // Connected or reconnected: fetch anything we missed meanwhile.
            unawaited(_safeSync(familyId));
          }
        });

    _subscription = channel;
  }

  /// Reads message IDs from a delivery/read ack. Supports the batched
  /// `message_ids` list (new) and the single `message_id` (older app versions).
  @visibleForTesting
  static Set<String> ackMessageIds(Map<String, dynamic> payload) {
    final ids = <String>{};
    final list = payload['message_ids'];
    if (list is List) {
      ids.addAll(list.map((e) => e.toString()).where((e) => e.isNotEmpty));
    }
    final single = payload['message_id']?.toString();
    if (single != null && single.isNotEmpty) ids.add(single);
    return ids;
  }

  /// Sends ONE read receipt broadcast for messages not acknowledged yet (F24).
  Future<void> markMessagesAsRead(List<String> messageIds) async {
    final channel = _subscription;
    if (channel == null) return;
    final fresh =
        messageIds.where((id) => !_readAckSent.contains(id)).toSet().toList();
    if (fresh.isEmpty) return;
    _readAckSent.addAll(fresh);
    try {
      await channel.sendBroadcastMessage(
        event: 'read_ack',
        payload: {
          'message_ids': fresh,
          // Older app versions only read a single id.
          'message_id': fresh.last,
          'reader_id': currentUserId,
        },
      );
    } catch (_) {
      _readAckSent.removeAll(fresh); // retry next time
    }
  }

  Future<void> _handleRealtimeMessage(Map<String, dynamic> msgRecord) async {
    final messageId = msgRecord['id'] as String?;
    if (messageId == null) return;

    // Soft deleted (tombstone)
    if (msgRecord['deleted_at'] != null) {
      await _db.markDeleted(messageId);
      return;
    }

    final senderId = msgRecord['sender_id'] as String?;
    // Our own message sent from THIS device is already stored. Messages we
    // sent from another device of ours still need decrypting here.
    if (senderId == currentUserId && await _db.hasMessage(messageId)) return;

    await _keyManager.ensureDeviceKeys();
    final myDeviceId = _keyManager.currentDeviceId;
    if (myDeviceId == null) return;

    final keyRow = await _client
        .from('message_keys')
        .select('locked_key')
        .eq('message_id', messageId)
        .eq('recipient_device_id', myDeviceId)
        .maybeSingle();

    if (keyRow == null) return; // Not a recipient of this message

    final stored =
        await _decryptAndStore(msgRecord, keyRow['locked_key'] as String);

    // Broadcast immediate Delivery ACK (Double Tick ✓✓) to sender
    if (stored && senderId != null && senderId != currentUserId) {
      try {
        await _subscription?.sendBroadcastMessage(
          event: 'delivery_ack',
          payload: {
            'message_id': messageId,
            'recipient_id': currentUserId,
          },
        );
      } catch (_) {}

      // Update unread badge count & trigger phone notification if thread is not open
      final audience = msgRecord['audience'] as String? ?? 'all';
      final threadKey = audience == 'selected' ? senderId : 'family';
      final openThread = _ref.read(activeOpenThreadProvider);
      if (openThread != threadKey) {
        final currentMap =
            Map<String, int>.from(_ref.read(unreadCountByThreadProvider));
        currentMap[threadKey] = (currentMap[threadKey] ?? 0) + 1;
        _ref.read(unreadCountByThreadProvider.notifier).state = currentMap;

        final totalUnread =
            currentMap.values.fold<int>(0, (sum, count) => sum + count);
        final familyId = msgRecord['family_id'] as String? ?? 'family';
        unawaited(
          NotificationService.showMessageNotification(
            id: messageId.hashCode & 0x7FFFFFFF,
            title: totalUnread > 1
                ? 'OurNest ($totalUnread new messages)'
                : 'OurNest — New Family Message',
            body: 'Tap to read your encrypted family message',
            payload: NotificationService.chatPayload(familyId),
            badgeCount: totalUnread,
          ),
        );
      }
    }
  }

  /// Clears unread count for [threadKey] ('family' or direct userId) and updates Android launcher badge
  Future<void> markThreadRead(String threadKey) async {
    final currentMap =
        Map<String, int>.from(_ref.read(unreadCountByThreadProvider));
    if ((currentMap[threadKey] ?? 0) > 0) {
      currentMap.remove(threadKey);
      _ref.read(unreadCountByThreadProvider.notifier).state = currentMap;
      final remaining =
          currentMap.values.fold<int>(0, (sum, count) => sum + count);
      await NotificationService.updateLauncherBadge(remaining);
    }
  }

  /// Decrypts a server message row with our sealed key and stores it locally.
  /// Returns false if it could not be decrypted (wrong key / corrupted).
  Future<bool> _decryptAndStore(
      Map<String, dynamic> msgRecord, String lockedKeyB64) async {
    final myPubKey = _keyManager.currentPublicKey;
    final myPrivKey = _keyManager.currentSecretKey;
    if (myPubKey == null || myPrivKey == null) return false;

    try {
      final unsealedKeyBytes = _crypto.openSealedMessageKey(
        lockedKeyBase64: lockedKeyB64,
        devicePublicKey: myPubKey,
        deviceSecretKey: myPrivKey,
      );

      final decryptedJson = _crypto.decryptMessagePayload(
        ciphertextBase64: msgRecord['ciphertext'] as String,
        nonceBase64: msgRecord['nonce'] as String,
        messageKeyBytes: unsealedKeyBytes,
      );

      final payload = MessagePayload.fromDecryptedJson(decryptedJson);
      final senderId = msgRecord['sender_id'] as String;
      final msgCreatedAt =
          DateTime.parse(msgRecord['created_at'] as String);

      // Update sender's lastSeen timestamp from message activity
      final seenMap =
          Map<String, DateTime>.from(_ref.read(lastSeenByUserProvider));
      final existingSeen = seenMap[senderId];
      if (existingSeen == null || msgCreatedAt.isAfter(existingSeen)) {
        seenMap[senderId] = msgCreatedAt;
        _ref.read(lastSeenByUserProvider.notifier).state = seenMap;
      }

      await _db.insertOrUpdateMessage(
        LocalMessagesCompanion(
          id: drift.Value(msgRecord['id'] as String),
          familyId: drift.Value(msgRecord['family_id'] as String),
          senderId: drift.Value(senderId),
          type: drift.Value(msgRecord['type'] as String),
          audience: drift.Value(msgRecord['audience'] as String),
          plaintext: drift.Value(decryptedJson),
          replyToId: drift.Value(payload.replyToId),
          recipientIds: payload.recipientIds != null
              ? drift.Value(payload.recipientIds!.join(','))
              : const drift.Value.absent(),
          isMine: drift.Value(senderId == currentUserId),
          createdAt:
              drift.Value(DateTime.parse(msgRecord['created_at'] as String)),
          editedAt: msgRecord['edited_at'] != null
              ? drift.Value(DateTime.parse(msgRecord['edited_at'] as String))
              : const drift.Value.absent(),
        ),
      );

      // Shared alarms: schedule escalation / cancel on "I'm awake" (F05).
      try {
        await _ref.read(alarmCoordinatorProvider).onMessageStored(
              messageType: msgRecord['type'] as String,
              plaintext: decryptedJson,
            );
      } catch (e) {
        debugPrint('Alarm scheduling failed for ${msgRecord['id']}: $e');
      }
      return true;
    } catch (e) {
      debugPrint('Could not decrypt message ${msgRecord['id']}: $e');
      return false;
    }
  }

  Future<void> _safeSync(String familyId) async {
    try {
      await syncMissedMessages(familyId);
    } catch (e) {
      debugPrint('Catch-up sync failed (will retry on next connect): $e');
    }
  }

  /// Fetches messages this device hasn't stored yet (sent while the app was
  /// closed/offline, or history after a reinstall, web reload or sign-in) and
  /// decrypts them (audit F02). Safe to call often: concurrent calls share one
  /// run, and already-stored messages are skipped. Returns how many new
  /// messages were stored.
  Future<int> syncMissedMessages(String familyId) {
    final running = _runningSync;
    if (running != null) return running;
    final future = _doSync(familyId).whenComplete(() => _runningSync = null);
    _runningSync = future;
    return future;
  }

  Future<int> _doSync(String familyId) async {
    if (currentUserId == null) return 0;
    await _keyManager.ensureDeviceKeys();
    final myDeviceId = _keyManager.currentDeviceId;
    if (myDeviceId == null) return 0;

    const columns =
        'id, family_id, sender_id, type, audience, ciphertext, nonce, created_at, edited_at, deleted_at';
    final latest = await _db.latestMessageTime(familyId);
    var stored = 0;

    if (latest == null) {
      // Nothing local: restore the most recent history.
      final rows = await _client
          .from('messages')
          .select(columns)
          .eq('family_id', familyId)
          .order('created_at', ascending: false)
          .limit(initialHistoryLimit);
      final list = List<Map<String, dynamic>>.from(rows as List).reversed.toList();
      stored += await _storeBatch(list, myDeviceId);
    } else {
      var since = latest.toUtc().subtract(syncOverlap);
      for (var page = 0; page < _maxPagesPerSync; page++) {
        final rows = await _client
            .from('messages')
            .select(columns)
            .eq('family_id', familyId)
            .gt('created_at', since.toIso8601String())
            .order('created_at', ascending: true)
            .limit(_pageSize);
        final list = List<Map<String, dynamic>>.from(rows as List);
        if (list.isEmpty) break;
        stored += await _storeBatch(list, myDeviceId);
        if (list.length < _pageSize) break;
        since = DateTime.parse(list.last['created_at'] as String).toUtc();
      }
    }

    await _syncRecentDeletions(familyId);
    return stored;
  }

  Future<int> _storeBatch(
      List<Map<String, dynamic>> rows, String myDeviceId) async {
    final toDecrypt = <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = row['id'] as String;
      if (row['deleted_at'] != null) {
        await _db.markDeleted(id);
      } else if (!await _db.hasMessage(id)) {
        toDecrypt.add(row);
      }
    }
    if (toDecrypt.isEmpty) return 0;

    // One query for all keys of this batch (no N+1).
    final keyRes = await _client
        .from('message_keys')
        .select('message_id, locked_key')
        .eq('recipient_device_id', myDeviceId)
        .inFilter('message_id', toDecrypt.map((r) => r['id']).toList());
    final keysByMessage = {
      for (final k in (keyRes as List))
        k['message_id'] as String: k['locked_key'] as String,
    };

    var stored = 0;
    for (final row in toDecrypt) {
      final lockedKey = keysByMessage[row['id']];
      // No key = sent before this device was registered; can't be decrypted.
      if (lockedKey == null) continue;
      if (await _decryptAndStore(row, lockedKey)) stored++;
    }
    return stored;
  }

  /// Applies "delete for everyone" made in the last 7 days to local copies.
  Future<void> _syncRecentDeletions(String familyId) async {
    final since =
        DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String();
    final rows = await _client
        .from('messages')
        .select('id')
        .eq('family_id', familyId)
        .gt('deleted_at', since);
    for (final r in (rows as List)) {
      final id = r['id'] as String;
      if (await _db.hasMessage(id)) await _db.markDeleted(id);
    }
  }

  /// Deletes a message ("delete for everyone" tombstone)
  Future<void> deleteMessage(String messageId) async {
    await _client.from('messages').update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
      'ciphertext': 'tombstone',
      'nonce': 'tombstone',
    }).eq('id', messageId);

    await _db.markDeleted(messageId);
  }

  void dispose() {
    _subscription?.unsubscribe();
    _subscription = null;
    _subscribedFamilyId = null;
  }

  /// Stops realtime sync and forgets in-memory presence / receipt state.
  void resetForSignOut() {
    dispose();
    _readAckSent.clear();
    _ref.read(onlineUserIdsProvider.notifier).state = <String>{};
    _ref.read(lastSeenByUserProvider.notifier).state = <String, DateTime>{};
    _ref.read(unreadCountByThreadProvider.notifier).state = <String, int>{};
    _ref.read(activeOpenThreadProvider.notifier).state = null;
    _ref.read(deliveredMessageIdsProvider.notifier).state = <String>{};
    _ref.read(readMessageIdsProvider.notifier).state = <String>{};
    unawaited(NotificationService.updateLauncherBadge(0));
  }
}
