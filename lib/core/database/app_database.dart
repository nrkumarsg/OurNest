import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connection/connection_stub.dart'
    if (dart.library.io) 'connection/connection_native.dart'
    if (dart.library.js_interop) 'connection/connection_web.dart';

part 'app_database.g.dart';

class LocalMessages extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text()();
  TextColumn get senderId => text()();
  TextColumn get senderName => text().nullable()();
  TextColumn get type => text()(); // 'text' | 'photo' | 'voice' | 'alarm' | 'alarm_event'
  TextColumn get audience => text()(); // 'all' | 'selected'
  TextColumn get plaintext => text()(); // decrypted content (stored locally only!)
  TextColumn get replyToId => text().nullable()();
  TextColumn get recipientIds => text().nullable()(); // comma separated
  BoolColumn get isMine => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get editedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [LocalMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openDriftConnection());

  @override
  int get schemaVersion => 1;

  // Web / PWA in-memory reactive message store (avoids needing external sqlite3.wasm)
  final Map<String, LocalMessage> _webMessages = {};
  final StreamController<void> _webChanges =
      StreamController<void>.broadcast();

  List<LocalMessage> _filterWebFamilyMessages(String familyId) {
    final list = _webMessages.values
        .where((t) => t.familyId == familyId && t.audience == 'all')
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  List<LocalMessage> _filterWebDirectMessages({
    required String familyId,
    required String otherUserId,
    required String myUserId,
  }) {
    final list = _webMessages.values
        .where((t) =>
            t.familyId == familyId &&
            t.audience == 'selected' &&
            (t.senderId == otherUserId || t.senderId == myUserId))
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  // Queries
  Stream<List<LocalMessage>> watchFamilyMessages(String familyId) {
    if (kIsWeb) {
      return Stream.multi((controller) {
        controller.add(_filterWebFamilyMessages(familyId));
        final sub = _webChanges.stream.listen((_) {
          controller.add(_filterWebFamilyMessages(familyId));
        });
        controller.onCancel = sub.cancel;
      });
    }
    return (select(localMessages)
          ..where((t) => t.familyId.equals(familyId) & t.audience.equals('all'))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .watch();
  }

  Stream<List<LocalMessage>> watchDirectMessages({
    required String familyId,
    required String otherUserId,
    required String myUserId,
  }) {
    if (kIsWeb) {
      return Stream.multi((controller) {
        controller.add(_filterWebDirectMessages(
          familyId: familyId,
          otherUserId: otherUserId,
          myUserId: myUserId,
        ));
        final sub = _webChanges.stream.listen((_) {
          controller.add(_filterWebDirectMessages(
            familyId: familyId,
            otherUserId: otherUserId,
            myUserId: myUserId,
          ));
        });
        controller.onCancel = sub.cancel;
      });
    }
    return (select(localMessages)
          ..where((t) =>
              t.familyId.equals(familyId) &
              t.audience.equals('selected') &
              (t.senderId.equals(otherUserId) | t.senderId.equals(myUserId)))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<void> insertOrUpdateMessage(LocalMessagesCompanion message) async {
    if (kIsWeb) {
      final id = message.id.value;
      final existing = _webMessages[id];
      _webMessages[id] = LocalMessage(
        id: id,
        familyId: message.familyId.present
            ? message.familyId.value
            : (existing?.familyId ?? ''),
        senderId: message.senderId.present
            ? message.senderId.value
            : (existing?.senderId ?? ''),
        senderName: message.senderName.present
            ? message.senderName.value
            : existing?.senderName,
        type: message.type.present
            ? message.type.value
            : (existing?.type ?? 'text'),
        audience: message.audience.present
            ? message.audience.value
            : (existing?.audience ?? 'all'),
        plaintext: message.plaintext.present
            ? message.plaintext.value
            : (existing?.plaintext ?? ''),
        replyToId: message.replyToId.present
            ? message.replyToId.value
            : existing?.replyToId,
        recipientIds: message.recipientIds.present
            ? message.recipientIds.value
            : existing?.recipientIds,
        isMine: message.isMine.present
            ? message.isMine.value
            : (existing?.isMine ?? false),
        createdAt: message.createdAt.present
            ? message.createdAt.value
            : (existing?.createdAt ?? DateTime.now()),
        editedAt: message.editedAt.present
            ? message.editedAt.value
            : existing?.editedAt,
        deletedAt: message.deletedAt.present
            ? message.deletedAt.value
            : existing?.deletedAt,
      );
      _webChanges.add(null);
      return;
    }
    await into(localMessages).insertOnConflictUpdate(message);
  }

  Future<void> markDeleted(String messageId) async {
    if (kIsWeb) {
      final existing = _webMessages[messageId];
      if (existing != null) {
        _webMessages[messageId] = existing.copyWith(
          deletedAt: Value(DateTime.now()),
          plaintext: 'This message was deleted',
        );
        _webChanges.add(null);
      }
      return;
    }
    await (update(localMessages)..where((t) => t.id.equals(messageId))).write(
      LocalMessagesCompanion(
        deletedAt: Value(DateTime.now()),
        plaintext: const Value('This message was deleted'),
      ),
    );
  }

  /// Removes every locally cached (decrypted) message. Called on sign-out so
  /// the next person to use this device can't read them (audit F11).
  Future<void> clearAllMessages() async {
    if (kIsWeb) {
      _webMessages.clear();
      _webChanges.add(null);
      return;
    }
    await delete(localMessages).go();
  }

  Future<void> updatePlaintext(String messageId, String newPlaintext) async {
    if (kIsWeb) {
      final existing = _webMessages[messageId];
      if (existing != null) {
        _webMessages[messageId] = existing.copyWith(
          plaintext: newPlaintext,
          editedAt: Value(DateTime.now()),
        );
        _webChanges.add(null);
      }
      return;
    }
    await (update(localMessages)..where((t) => t.id.equals(messageId))).write(
      LocalMessagesCompanion(
        plaintext: Value(newPlaintext),
        editedAt: Value(DateTime.now()),
      ),
    );
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});
