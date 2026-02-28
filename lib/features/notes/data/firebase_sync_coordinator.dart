import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/folder.dart';
import '../domain/models/note.dart';
import 'local_database.dart';

class FirebaseSyncCoordinator {
  FirebaseSyncCoordinator({
    required FirebaseFirestore firestore,
    required this.userId,
    required LocalDatabase database,
  })  : _firestore = firestore,
        _database = database;

  final FirebaseFirestore _firestore;
  final String userId;
  final LocalDatabase _database;
  final Random _random = Random();

  static const int _pullBatchSize = 200;
  static const int _pushBatchSize = 200;

  StreamSubscription<void>? _syncQueueSubscription;
  StreamSubscription<QuerySnapshot>? _notesSubscription;
  StreamSubscription<QuerySnapshot>? _foldersSubscription;
  bool _isSyncing = false;
  bool _syncRequested = false;

  void start() {
    _syncQueueSubscription?.cancel();
    _syncQueueSubscription = _database.syncQueueChanged.listen((_) {
      unawaited(syncNow());
    });

    _notesSubscription?.cancel();
    _notesSubscription = _collectionForType(LocalDatabase.entityTypeNote)
        .orderBy('server_updated_at', descending: true)
        .limit(1)
        .snapshots()
        .listen((_) {
      unawaited(syncNow());
    });

    _foldersSubscription?.cancel();
    _foldersSubscription = _collectionForType(LocalDatabase.entityTypeFolder)
        .orderBy('server_updated_at', descending: true)
        .limit(1)
        .snapshots()
        .listen((_) {
      unawaited(syncNow());
    });

    unawaited(syncNow());
  }

  void dispose() {
    _syncQueueSubscription?.cancel();
    _notesSubscription?.cancel();
    _foldersSubscription?.cancel();
  }

  Future<void> syncNow() async {
    if (_isSyncing) {
      _syncRequested = true;
      return;
    }
    _isSyncing = true;
    _syncRequested = false;
    
    try {
      await _pushOutbox();
      await _pullEntity(LocalDatabase.entityTypeNote);
      await _pullEntity(LocalDatabase.entityTypeFolder);
    } catch (error, stackTrace) {
      debugPrint('SYNC_ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isSyncing = false;
      if (_syncRequested) {
        unawaited(syncNow());
      }
    }
  }

  Future<void> _pushOutbox() async {
    for (var i = 0; i < 10; i++) {
      final pending = await _database.pendingOperations(limit: _pushBatchSize);
      if (pending.isEmpty) return;

      for (final operation in pending) {
        try {
          await _pushOperation(operation);
          await _database.markOperationSucceeded(operation.opId);
        } catch (_) {
          final nextRetryCount = operation.retryCount + 1;
          await _database.markOperationFailed(
            opId: operation.opId,
            retryCount: nextRetryCount,
            nextRetryAtMs: _nextRetryAtMs(nextRetryCount),
          );
        }
      }
    }
  }

  Future<void> _pushOperation(SyncQueueOperation operation) async {
    final collection = _collectionForType(operation.entityType);
    final document = collection.doc(operation.entityId);

    if (operation.opType == LocalDatabase.opTypeDelete) {
      await document.set(
        <String, Object?>{
          'id': operation.entityId,
          'is_deleted': true,
          'server_updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return;
    }

    if (operation.opType != LocalDatabase.opTypeUpsert || operation.payload == null) {
      return;
    }

    final payload = jsonDecode(operation.payload!) as Map<String, dynamic>;
    payload['id'] = operation.entityId;
    payload['is_deleted'] = false;
    payload['server_updated_at'] = FieldValue.serverTimestamp();

    await document.set(payload, SetOptions(merge: true));
  }

  Future<void> _pullEntity(String entityType) async {
    final cursor = await _database.readCursor(entityType);
    if (cursor.timestampMs == null) {
      await _bootstrapEntity(entityType);
      return;
    }

    var cursorTimestampMs = cursor.timestampMs!;
    var cursorId = cursor.lastId ?? '';

    for (var i = 0; i < 10; i++) {
      Query<Map<String, dynamic>> query = _collectionForType(entityType)
          .orderBy('server_updated_at')
          .orderBy('id')
          .startAfter(
        <Object>[
          Timestamp.fromMillisecondsSinceEpoch(cursorTimestampMs),
          cursorId,
        ],
      );

      final snapshot = await query.limit(_pullBatchSize).get();
      if (snapshot.docs.isEmpty) return;

      for (final doc in snapshot.docs) {
        final payload = Map<String, dynamic>.from(doc.data());
        final docId = _effectiveDocId(doc.id, payload['id']);
        final remoteUpdatedAtMs =
            _extractRemoteUpdatedAtMs(payload) ?? DateTime.now().millisecondsSinceEpoch;

        final hasPending = await _database.hasPendingOperation(
          entityType: entityType,
          entityId: docId,
        );
        if (!hasPending) {
          await _applyRemoteDocument(
            entityType: entityType,
            docId: docId,
            payload: payload,
            remoteUpdatedAtMs: remoteUpdatedAtMs,
          );
        }

        if (_isCursorAfter(
          newTimestampMs: remoteUpdatedAtMs,
          newId: docId,
          currentTimestampMs: cursorTimestampMs,
          currentId: cursorId,
        )) {
          cursorTimestampMs = remoteUpdatedAtMs;
          cursorId = docId;
        }
      }

      await _database.writeCursor(
        entityType: entityType,
        timestampMs: cursorTimestampMs,
        lastId: cursorId,
      );

      if (snapshot.docs.length < _pullBatchSize) return;
    }
  }

  Future<void> _bootstrapEntity(String entityType) async {
    final snapshot = await _collectionForType(entityType).get();

    var maxTimestampMs = 0;
    var maxId = '';

    for (final doc in snapshot.docs) {
      final payload = Map<String, dynamic>.from(doc.data());
      final docId = _effectiveDocId(doc.id, payload['id']);
      final remoteUpdatedAtMs =
          _extractRemoteUpdatedAtMs(payload) ?? DateTime.now().millisecondsSinceEpoch;

      final hasPending = await _database.hasPendingOperation(
        entityType: entityType,
        entityId: docId,
      );
      if (!hasPending) {
        await _applyRemoteDocument(
          entityType: entityType,
          docId: docId,
          payload: payload,
          remoteUpdatedAtMs: remoteUpdatedAtMs,
        );
      }

      if (_isCursorAfter(
        newTimestampMs: remoteUpdatedAtMs,
        newId: docId,
        currentTimestampMs: maxTimestampMs,
        currentId: maxId,
      )) {
        maxTimestampMs = remoteUpdatedAtMs;
        maxId = docId;
      }

      if (payload['server_updated_at'] == null ||
          payload['id'] == null ||
          !payload.containsKey('is_deleted')) {
        await doc.reference.set(
          <String, Object?>{
            'id': docId,
            'is_deleted': payload['is_deleted'] == true,
            'server_updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    if (maxTimestampMs == 0) {
      maxTimestampMs = DateTime.now().millisecondsSinceEpoch;
    }

    await _database.writeCursor(
      entityType: entityType,
      timestampMs: maxTimestampMs,
      lastId: maxId,
    );
  }

  Future<void> _applyRemoteDocument({
    required String entityType,
    required String docId,
    required Map<String, dynamic> payload,
    required int remoteUpdatedAtMs,
  }) async {
    final isDeleted = payload['is_deleted'] == true;
    payload.remove('server_updated_at');
    payload.remove('is_deleted');
    payload['id'] = docId;

    try {
      if (entityType == LocalDatabase.entityTypeNote) {
        if (isDeleted) {
          await _database.markNoteDeleted(
            docId,
            source: SyncWriteSource.remote,
            remoteUpdatedAtMs: remoteUpdatedAtMs,
          );
          return;
        }

        final note = Note.fromJson(payload);
        await _database.upsertNote(
          note,
          source: SyncWriteSource.remote,
          remoteUpdatedAtMs: remoteUpdatedAtMs,
        );
        return;
      }

      if (entityType == LocalDatabase.entityTypeFolder) {
        if (isDeleted) {
          await _database.markFolderDeleted(
            docId,
            source: SyncWriteSource.remote,
            remoteUpdatedAtMs: remoteUpdatedAtMs,
          );
          return;
        }

        final folder = Folder.fromJson(payload);
        await _database.upsertFolder(
          folder,
          source: SyncWriteSource.remote,
          remoteUpdatedAtMs: remoteUpdatedAtMs,
        );
      }
    } catch (_) {
      return;
    }
  }

  CollectionReference<Map<String, dynamic>> _collectionForType(String entityType) {
    if (entityType == LocalDatabase.entityTypeNote) {
      return _firestore.collection('users').doc(userId).collection('notes');
    }
    return _firestore.collection('users').doc(userId).collection('folders');
  }

  int _nextRetryAtMs(int retryCount) {
    final baseSeconds = min(1800, 5 * (1 << min(retryCount, 8)));
    final jitterSeconds = _random.nextInt(4);
    return DateTime.now()
        .add(Duration(seconds: baseSeconds + jitterSeconds))
        .millisecondsSinceEpoch;
  }

  static String _effectiveDocId(String fallbackDocId, dynamic idField) {
    if (idField is String && idField.isNotEmpty) {
      return idField;
    }
    return fallbackDocId;
  }

  static int? _extractRemoteUpdatedAtMs(Map<String, dynamic> payload) {
    final server = _toMilliseconds(payload['server_updated_at']);
    if (server != null) return server;

    final updated = _toMilliseconds(payload['updatedAt']);
    if (updated != null) return updated;

    final created = _toMilliseconds(payload['createdAt']);
    if (created != null) return created;

    return null;
  }

  static int? _toMilliseconds(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final directInt = int.tryParse(value);
      if (directInt != null) return directInt;
      final parsedDate = DateTime.tryParse(value);
      if (parsedDate != null) return parsedDate.millisecondsSinceEpoch;
    }
    return null;
  }

  static bool _isCursorAfter({
    required int newTimestampMs,
    required String newId,
    required int currentTimestampMs,
    required String currentId,
  }) {
    if (newTimestampMs > currentTimestampMs) return true;
    if (newTimestampMs < currentTimestampMs) return false;
    return newId.compareTo(currentId) > 0;
  }
}
