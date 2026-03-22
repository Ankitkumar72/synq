import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/folder.dart';
import '../domain/models/note.dart';

enum SyncWriteSource { local, remote }

class SyncCursor {
  const SyncCursor({required this.timestampMs, required this.lastId});

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
  LocalDatabase(this._userId);

  final String _userId;

  static const String _queuePending = 'pending';
  static const String entityTypeNote = 'note';
  static const String entityTypeFolder = 'folder';
  static const String opTypeUpsert = 'upsert';
  static const String opTypeDelete = 'delete';
  static const int staleDaysThreshold = 30;
  static const int sizeWarningBytes = 50 * 1024 * 1024; // 50 MB

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

  Stream<Note?> watchNote(String id) async* {
    yield await getNote(id);
    yield* _notesChangedController.stream.asyncMap((_) => getNote(id));
  }

  Stream<List<Note>> watchFilteredNotes({
    bool? isCompleted,
    bool? isTask,
    int? scheduledBeforeMs,
    int? scheduledAfterMs,
    String? folderId,
  }) async* {
    yield await getFilteredNotes(
      isCompleted: isCompleted,
      isTask: isTask,
      scheduledBeforeMs: scheduledBeforeMs,
      scheduledAfterMs: scheduledAfterMs,
      folderId: folderId,
    );
    yield* _notesChangedController.stream.asyncMap((_) => getFilteredNotes(
          isCompleted: isCompleted,
          isTask: isTask,
          scheduledBeforeMs: scheduledBeforeMs,
          scheduledAfterMs: scheduledAfterMs,
          folderId: folderId,
        ));
  }

  Future<Note?> getNote(String id) async {
    final db = await _openDatabase();
    final rows = await db.query(
      'notes',
      columns: <String>['payload'],
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final rawPayload = rows.first['payload'] as String;
    if (rawPayload.isEmpty) return null;

    try {
      final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
      return Note.fromJson(payload);
    } catch (_) {
      return null;
    }
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

  Future<List<Note>> getFilteredNotes({
    bool? isCompleted,
    bool? isTask,
    int? scheduledBeforeMs,
    int? scheduledAfterMs,
    String? folderId,
  }) async {
    final db = await _openDatabase();
    
    final conditions = <String>['is_deleted = 0'];
    final args = <Object>[];

    if (isCompleted != null) {
      conditions.add('is_completed = ?');
      args.add(isCompleted ? 1 : 0);
    }
    if (isTask != null) {
      conditions.add('is_task = ?');
      args.add(isTask ? 1 : 0);
    }
    if (scheduledBeforeMs != null) {
      conditions.add('scheduled_time_ms < ?');
      args.add(scheduledBeforeMs);
    }
    if (scheduledAfterMs != null) {
      conditions.add('scheduled_time_ms >= ?');
      args.add(scheduledAfterMs);
    }
    if (folderId != null) {
      conditions.add('folder_id = ?');
      args.add(folderId);
    }

    final rows = await db.query(
      'notes',
      columns: <String>['payload'],
      where: conditions.join(' AND '),
      whereArgs: args.isNotEmpty ? args : null,
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

    // Default sorting for filtered results can be optimized later inside SQL using updated_at_ms or scheduled_time_ms
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
    final updatedAtMs =
        remoteUpdatedAtMs ??
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

      await txn.insert('notes', <String, Object?>{
        'id': note.id,
        'payload': jsonEncode(note.toJson()),
        'updated_at_ms': updatedAtMs,
        'is_deleted': 0,
        'scheduled_time_ms': note.scheduledTime?.millisecondsSinceEpoch,
        'end_time_ms': note.endTime?.millisecondsSinceEpoch,
        'is_completed': note.isCompleted ? 1 : 0,
        'is_task': note.isTask ? 1 : 0,
        'priority': note.priority.name,
        'category': note.category.name,
        'folder_id': note.folderId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

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
    final updatedAtMs =
        remoteUpdatedAtMs ?? DateTime.now().millisecondsSinceEpoch;

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

      await txn.insert('folders', <String, Object?>{
        'id': folder.id,
        'payload': jsonEncode(folder.toJson()),
        'updated_at_ms': updatedAtMs,
        'is_deleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

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
    final updatedAtMs =
        remoteUpdatedAtMs ?? DateTime.now().millisecondsSinceEpoch;

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

      await txn.insert('notes', <String, Object?>{
        'id': noteId,
        'payload': '{}',
        'updated_at_ms': updatedAtMs,
        'is_deleted': 1,
        'scheduled_time_ms': null,
        'end_time_ms': null,
        'is_completed': 0,
        'is_task': 0,
        'priority': null,
        'category': null,
        'folder_id': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

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
        await txn.insert('notes', <String, Object?>{
          'id': noteId,
          'payload': '{}',
          'updated_at_ms': updatedAtMs,
          'is_deleted': 1,
          'scheduled_time_ms': null,
          'end_time_ms': null,
          'is_completed': 0,
          'is_task': 0,
          'priority': null,
          'category': null,
          'folder_id': null,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

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
    final updatedAtMs =
        remoteUpdatedAtMs ?? DateTime.now().millisecondsSinceEpoch;

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

      await txn.insert('folders', <String, Object?>{
        'id': folderId,
        'payload': '{}',
        'updated_at_ms': updatedAtMs,
        'is_deleted': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

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

    return SyncCursor(timestampMs: timestampMs, lastId: lastId);
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
      await txn.insert('sync_state', <String, Object?>{
        'key': tsKey,
        'value': '$timestampMs',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('sync_state', <String, Object?>{
        'key': idKey,
        'value': lastId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Deletes all rows from notes, folders, sync_queue, and sync_state.
  /// Used by the "Clear Offline Data" button — NOT called on logout.
  Future<void> clearAllData() async {
    final db = await _openDatabase();
    await db.transaction((txn) async {
      await txn.delete('notes');
      await txn.delete('folders');
      await txn.delete('sync_queue');
      await txn.delete('sync_state');
    });
    _notesChangedController.add(null);
    _foldersChangedController.add(null);
  }

  /// Returns the current DB file size in bytes.
  Future<int> dbFileSizeBytes() async {
    final basePath = await getDatabasesPath();
    final file = File(path.join(basePath, 'synq_$_userId.db'));
    if (await file.exists()) return await file.length();
    return 0;
  }

  /// Deletes synq_*.db files not accessed in [staleDaysThreshold] days,
  /// excluding the current user's DB. Also always deletes the anonymous DB.
  /// Uses `.lastopen` sidecar files for reliable cross-platform staleness
  /// detection (iOS does not reliably update file-system timestamps on
  /// SQLite WAL databases).
  static Future<void> deleteStaleDbFiles(String currentUserId) async {
    final basePath = await getDatabasesPath();
    final dir = Directory(basePath);
    if (!await dir.exists()) return;
    final cutoffMs = DateTime.now()
        .subtract(const Duration(days: staleDaysThreshold))
        .millisecondsSinceEpoch;
    final currentFileName = 'synq_$currentUserId.db';
    const anonymousFileName = 'synq__anonymous.db';

    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = path.basename(entity.path);
      if (!name.startsWith('synq_') || !name.endsWith('.db')) continue;
      if (name == currentFileName) continue;

      // Always delete the anonymous DB — it's a throwaway session.
      if (name == anonymousFileName) {
        await _deleteSidecarAndDb(entity);
        continue;
      }

      // Read the .lastopen sidecar to decide staleness.
      final sidecarPath =
          '${entity.path.substring(0, entity.path.length - 3)}.lastopen';
      final sidecar = File(sidecarPath);
      if (await sidecar.exists()) {
        final raw = (await sidecar.readAsString()).trim();
        final lastOpenedMs = int.tryParse(raw);
        if (lastOpenedMs != null && lastOpenedMs < cutoffMs) {
          await _deleteSidecarAndDb(entity);
        }
      } else {
        // No sidecar → very old DB from before this logic existed. Delete it.
        await entity.delete();
      }
    }
  }

  static Future<void> _deleteSidecarAndDb(File dbFile) async {
    final sidecarPath =
        '${dbFile.path.substring(0, dbFile.path.length - 3)}.lastopen';
    final sidecar = File(sidecarPath);
    if (await sidecar.exists()) await sidecar.delete();
    // Delete main DB + SQLite WAL companion files.
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('${dbFile.path}$suffix');
      if (await f.exists()) await f.delete();
    }
  }

  Future<Database> _openDatabase() async {
    if (_database != null) return _database!;

    final basePath = await getDatabasesPath();
    final databasePath = path.join(basePath, 'synq_$_userId.db');
    _database = await openDatabase(
      databasePath,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at_ms INTEGER NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            scheduled_time_ms INTEGER,
            end_time_ms INTEGER,
            is_completed INTEGER NOT NULL DEFAULT 0,
            is_task INTEGER NOT NULL DEFAULT 0,
            priority TEXT,
            category TEXT,
            folder_id TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX notes_active_idx ON notes(is_deleted, updated_at_ms DESC)',
        );
        await db.execute(
          'CREATE INDEX notes_scheduled_idx ON notes(is_deleted, is_completed, scheduled_time_ms)',
        );
        await db.execute(
          'CREATE INDEX notes_folder_idx ON notes(is_deleted, folder_id)',
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE notes ADD COLUMN scheduled_time_ms INTEGER');
          await db.execute('ALTER TABLE notes ADD COLUMN end_time_ms INTEGER');
          await db.execute('ALTER TABLE notes ADD COLUMN is_completed INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE notes ADD COLUMN is_task INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE notes ADD COLUMN priority TEXT');
          await db.execute('ALTER TABLE notes ADD COLUMN category TEXT');
          await db.execute('ALTER TABLE notes ADD COLUMN folder_id TEXT');

          await db.execute(
            'CREATE INDEX notes_scheduled_idx ON notes(is_deleted, is_completed, scheduled_time_ms)',
          );
          await db.execute(
            'CREATE INDEX notes_folder_idx ON notes(is_deleted, folder_id)',
          );

          // Migrate data
          int? parseMs(dynamic value) {
            if (value == null) return null;
            if (value is int) return value;
            if (value is String) {
              try {
                return DateTime.parse(value).millisecondsSinceEpoch;
              } catch (_) {
                return null;
              }
            }
            return null;
          }

          final rows = await db.query('notes', columns: ['id', 'payload']);
          final batch = db.batch();
          for (final row in rows) {
            try {
              final payloadRaw = row['payload'];
              if (payloadRaw is! String) continue;
              final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
              
              final isCompleted = payload['isCompleted'] as bool? ?? false;
              final isTask = payload['isTask'] as bool? ?? false;
              final priority = payload['priority'] as String?;
              final category = payload['category'] as String?;
              final folderId = payload['folderId'] as String?;

              final scheduledTimeMs = parseMs(payload['scheduledTime']);
              final endTimeMs = parseMs(payload['endTime']);

              batch.update(
                'notes',
                {
                  'scheduled_time_ms': scheduledTimeMs,
                  'end_time_ms': endTimeMs,
                  'is_completed': isCompleted ? 1 : 0,
                  'is_task': isTask ? 1 : 0,
                  'priority': priority,
                  'category': category,
                  'folder_id': folderId,
                },
                where: 'id = ?',
                whereArgs: [row['id']],
              );
            } catch (_) {
              // skip invalid payloads
            }
          }
          await batch.commit(noResult: true);
        }
      },
    );
    await _touchLastOpenFile();
    return _database!;
  }

  /// Writes the current epoch ms to a `.lastopen` sidecar file next to the DB.
  /// Used by [deleteStaleDbFiles] for iOS-safe staleness detection.
  Future<void> _touchLastOpenFile() async {
    try {
      final basePath = await getDatabasesPath();
      final sidecar = File(path.join(basePath, 'synq_$_userId.lastopen'));
      await sidecar.writeAsString('${DateTime.now().millisecondsSinceEpoch}');
    } catch (_) {
      // Non-critical — staleness detection degrades gracefully.
    }
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

    await txn.insert('sync_queue', <String, Object?>{
      'op_id': _uuid.v4(),
      'entity_type': entityType,
      'entity_id': entityId,
      'op_type': opType,
      'payload': payload,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
      'next_retry_at_ms': null,
      'status': _queuePending,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

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
