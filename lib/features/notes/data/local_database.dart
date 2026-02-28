import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/folder.dart';
import '../domain/models/note.dart';

enum SyncWriteSource { local, remote }

class SyncCursor {
  const SyncCursor({
    required this.timestampMs,
    required this.lastId,
  });

  final int? timestampMs;
  final String? lastId;
}

class SyncQueueOperation {
  const SyncQueueOperation({
    required this.opId,
    required this.entityType,
    required this.entityId,
    required this.opType,
    required this.payload,
    required this.retryCount,
    required this.createdAtMs,
  });

  final String opId;
  final String entityType;
  final String entityId;
  final String opType;
  final String? payload;
  final int retryCount;
  final int createdAtMs;
}

class LocalDatabase {
  static const String _databaseName = 'synq_local.db';
  static const String _queuePending = 'pending';
  static const String entityTypeNote = 'note';
  static const String entityTypeFolder = 'folder';
  static const String opTypeUpsert = 'upsert';
  static const String opTypeDelete = 'delete';

  final Uuid _uuid = const Uuid();
  Database? _database;
  bool _isClosed = false;

  final StreamController<void> _notesChangedController =
      StreamController<void>.broadcast();
  final StreamController<void> _foldersChangedController =
      StreamController<void>.broadcast();
  final StreamController<void> _syncQueueChangedController =
      StreamController<void>.broadcast();

  Stream<void> get syncQueueChanged => _syncQueueChangedController.stream;

  Future<void> dispose() async {
    if (_isClosed) return;
    _isClosed = true;

    await _notesChangedController.close();
    await _foldersChangedController.close();
    await _syncQueueChangedController.close();
    await _database?.close();
    _database = null;
  }

  Stream<List<Note>> watchNotes() async* {
    yield await getNotes();
    yield* _notesChangedController.stream.asyncMap((_) => getNotes());
  }

  Stream<List<Folder>> watchFolders() async* {
    yield await getFolders();
    yield* _foldersChangedController.stream.asyncMap((_) => getFolders());
  }

  Future<List<Note>> getNotes() async {
    final db = await _openDatabase();
    final rows = await db.query(
      'notes',
      columns: <String>['payload'],
      where: 'is_deleted = 0',
    );

    final notes = <Note>[];
    for (final row in rows) {
      final rawPayload = row['payload'];
      if (rawPayload is! String || rawPayload.isEmpty) continue;

      try {
        final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
        notes.add(Note.fromJson(payload));
      } catch (_) {
        continue;
      }
    }

    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes;
  }

  Future<List<Folder>> getFolders() async {
    final db = await _openDatabase();
    final rows = await db.query(
      'folders',
      columns: <String>['payload'],
      where: 'is_deleted = 0',
    );

    final folders = <Folder>[];
    for (final row in rows) {
      final rawPayload = row['payload'];
      if (rawPayload is! String || rawPayload.isEmpty) continue;

      try {
        final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
        folders.add(Folder.fromJson(payload));
      } catch (_) {
        continue;
      }
    }

    folders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return folders;
  }

  Future<void> upsertNote(
    Note note, {
    required SyncWriteSource source,
    int? remoteUpdatedAtMs,
  }) async {
    final db = await _openDatabase();
    final updatedAtMs = remoteUpdatedAtMs ??
        note.updatedAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final localUpdatedAtMs = await _currentUpdatedAtMs(
        txn: txn,
        table: 'notes',
        id: note.id,
      );
      if (source == SyncWriteSource.remote &&
          localUpdatedAtMs != null &&
          localUpdatedAtMs > updatedAtMs) {
        return;
      }

      await txn.insert(
        'notes',
        <String, Object?>{
          'id': note.id,
          'payload': jsonEncode(note.toJson()),
          'updated_at_ms': updatedAtMs,
          'is_deleted': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (source == SyncWriteSource.local) {
        await _enqueueOperation(
          txn: txn,
          entityType: entityTypeNote,
          entityId: note.id,
          opType: opTypeUpsert,
          payload: jsonEncode(note.toJson()),
        );
      }
    });

    _notesChangedController.add(null);
  }

  Future<void> upsertFolder(
    Folder folder, {
    required SyncWriteSource source,
    int? remoteUpdatedAtMs,
  }) async {
    final db = await _openDatabase();
    final updatedAtMs = remoteUpdatedAtMs ?? DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final localUpdatedAtMs = await _currentUpdatedAtMs(
        txn: txn,
        table: 'folders',
        id: folder.id,
      );
      if (source == SyncWriteSource.remote &&
          localUpdatedAtMs != null &&
          localUpdatedAtMs > updatedAtMs) {
        return;
      }

      await txn.insert(
        'folders',
        <String, Object?>{
          'id': folder.id,
          'payload': jsonEncode(folder.toJson()),
          'updated_at_ms': updatedAtMs,
          'is_deleted': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (source == SyncWriteSource.local) {
        await _enqueueOperation(
          txn: txn,
          entityType: entityTypeFolder,
          entityId: folder.id,
          opType: opTypeUpsert,
          payload: jsonEncode(folder.toJson()),
        );
      }
    });

    _foldersChangedController.add(null);
  }

  Future<void> markNoteDeleted(
    String noteId, {
    required SyncWriteSource source,
    int? remoteUpdatedAtMs,
  }) async {
    final db = await _openDatabase();
    final updatedAtMs = remoteUpdatedAtMs ?? DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final localUpdatedAtMs = await _currentUpdatedAtMs(
        txn: txn,
        table: 'notes',
        id: noteId,
      );
      if (source == SyncWriteSource.remote &&
          localUpdatedAtMs != null &&
          localUpdatedAtMs > updatedAtMs) {
        return;
      }

      await txn.insert(
        'notes',
        <String, Object?>{
          'id': noteId,
          'payload': '{}',
          'updated_at_ms': updatedAtMs,
          'is_deleted': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (source == SyncWriteSource.local) {
        await _enqueueOperation(
          txn: txn,
          entityType: entityTypeNote,
          entityId: noteId,
          opType: opTypeDelete,
          payload: null,
        );
      }
    });

    _notesChangedController.add(null);
  }

  Future<void> markNotesDeleted(
    List<String> noteIds, {
    required SyncWriteSource source,
  }) async {
    if (noteIds.isEmpty) return;
    final db = await _openDatabase();
    final updatedAtMs = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      for (final noteId in noteIds) {
        await txn.insert(
          'notes',
          <String, Object?>{
            'id': noteId,
            'payload': '{}',
            'updated_at_ms': updatedAtMs,
            'is_deleted': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (source == SyncWriteSource.local) {
          await _enqueueOperation(
            txn: txn,
            entityType: entityTypeNote,
            entityId: noteId,
            opType: opTypeDelete,
            payload: null,
          );
        }
      }
    });

    _notesChangedController.add(null);
  }

  Future<void> markFolderDeleted(
    String folderId, {
    required SyncWriteSource source,
    int? remoteUpdatedAtMs,
  }) async {
    final db = await _openDatabase();
    final updatedAtMs = remoteUpdatedAtMs ?? DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final localUpdatedAtMs = await _currentUpdatedAtMs(
        txn: txn,
        table: 'folders',
        id: folderId,
      );
      if (source == SyncWriteSource.remote &&
          localUpdatedAtMs != null &&
          localUpdatedAtMs > updatedAtMs) {
        return;
      }

      await txn.insert(
        'folders',
        <String, Object?>{
          'id': folderId,
          'payload': '{}',
          'updated_at_ms': updatedAtMs,
          'is_deleted': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (source == SyncWriteSource.local) {
        await _enqueueOperation(
          txn: txn,
          entityType: entityTypeFolder,
          entityId: folderId,
          opType: opTypeDelete,
          payload: null,
        );
      }
    });

    _foldersChangedController.add(null);
  }

  Future<bool> hasPendingOperation({
    required String entityType,
    required String entityId,
  }) async {
    final db = await _openDatabase();
    final rows = await db.query(
      'sync_queue',
      columns: <String>['op_id'],
      where: 'entity_type = ? AND entity_id = ? AND status = ?',
      whereArgs: <Object>[entityType, entityId, _queuePending],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<SyncQueueOperation>> pendingOperations({int limit = 200}) async {
    final db = await _openDatabase();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'sync_queue',
      where:
          'status = ? AND (next_retry_at_ms IS NULL OR next_retry_at_ms <= ?)',
      whereArgs: <Object>[_queuePending, nowMs],
      orderBy: 'created_at_ms ASC',
      limit: limit,
    );

    return rows
        .map(
          (row) => SyncQueueOperation(
            opId: row['op_id'] as String,
            entityType: row['entity_type'] as String,
            entityId: row['entity_id'] as String,
            opType: row['op_type'] as String,
            payload: row['payload'] as String?,
            retryCount: (row['retry_count'] as num).toInt(),
            createdAtMs: (row['created_at_ms'] as num).toInt(),
          ),
        )
        .toList(growable: false);
  }

  Future<void> markOperationSucceeded(String opId) async {
    final db = await _openDatabase();
    await db.delete(
      'sync_queue',
      where: 'op_id = ?',
      whereArgs: <Object>[opId],
    );
  }

  Future<void> markOperationFailed({
    required String opId,
    required int retryCount,
    required int nextRetryAtMs,
  }) async {
    final db = await _openDatabase();
    await db.update(
      'sync_queue',
      <String, Object?>{
        'retry_count': retryCount,
        'next_retry_at_ms': nextRetryAtMs,
      },
      where: 'op_id = ?',
      whereArgs: <Object>[opId],
    );
  }

  Future<SyncCursor> readCursor(String entityType) async {
    final db = await _openDatabase();
    final tsKey = _cursorTimestampKey(entityType);
    final idKey = _cursorIdKey(entityType);
    final rows = await db.query(
      'sync_state',
      where: 'key = ? OR key = ?',
      whereArgs: <Object>[tsKey, idKey],
    );

    int? timestampMs;
    String? lastId;
    for (final row in rows) {
      final key = row['key'] as String;
      final value = row['value'] as String?;
      if (key == tsKey && value != null) {
        timestampMs = int.tryParse(value);
      } else if (key == idKey && value != null && value.isNotEmpty) {
        lastId = value;
      }
    }

    return SyncCursor(
      timestampMs: timestampMs,
      lastId: lastId,
    );
  }

  Future<void> writeCursor({
    required String entityType,
    required int timestampMs,
    required String lastId,
  }) async {
    final db = await _openDatabase();
    final tsKey = _cursorTimestampKey(entityType);
    final idKey = _cursorIdKey(entityType);

    await db.transaction((txn) async {
      await txn.insert(
        'sync_state',
        <String, Object?>{
          'key': tsKey,
          'value': '$timestampMs',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'sync_state',
        <String, Object?>{
          'key': idKey,
          'value': lastId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<Database> _openDatabase() async {
    if (_database != null) return _database!;

    final basePath = await getDatabasesPath();
    final databasePath = path.join(basePath, _databaseName);
    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at_ms INTEGER NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX notes_active_idx ON notes(is_deleted, updated_at_ms DESC)',
        );

        await db.execute('''
          CREATE TABLE folders (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at_ms INTEGER NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX folders_active_idx ON folders(is_deleted, updated_at_ms DESC)',
        );

        await db.execute('''
          CREATE TABLE sync_queue (
            op_id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            op_type TEXT NOT NULL,
            payload TEXT,
            created_at_ms INTEGER NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            next_retry_at_ms INTEGER,
            status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX sync_queue_pending_idx
          ON sync_queue(status, next_retry_at_ms, created_at_ms)
        ''');

        await db.execute('''
          CREATE TABLE sync_state (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
    return _database!;
  }

  Future<void> _enqueueOperation({
    required Transaction txn,
    required String entityType,
    required String entityId,
    required String opType,
    required String? payload,
  }) async {
    await txn.delete(
      'sync_queue',
      where: 'entity_type = ? AND entity_id = ? AND status = ?',
      whereArgs: <Object>[entityType, entityId, _queuePending],
    );

    await txn.insert(
      'sync_queue',
      <String, Object?>{
        'op_id': _uuid.v4(),
        'entity_type': entityType,
        'entity_id': entityId,
        'op_type': opType,
        'payload': payload,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
        'retry_count': 0,
        'next_retry_at_ms': null,
        'status': _queuePending,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _syncQueueChangedController.add(null);
  }

  Future<int?> _currentUpdatedAtMs({
    required Transaction txn,
    required String table,
    required String id,
  }) async {
    final rows = await txn.query(
      table,
      columns: <String>['updated_at_ms'],
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['updated_at_ms'];
    return value is num ? value.toInt() : null;
  }

  static String _cursorTimestampKey(String entityType) {
    return '$entityType.cursor.timestamp';
  }

  static String _cursorIdKey(String entityType) {
    return '$entityType.cursor.id';
  }
}
