import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/crdt/hlc.dart';
import '../../../core/crdt/field_level_crdt.dart';
import '../../../core/database/local_database.dart';
import '../../notes/domain/models/note.dart';
import '../../../core/constants/database_constants.dart';

/// Handles note-specific sync operations between local SQLite and Supabase.
///
/// Responsibilities:
///   - Pushing notes from the outbox to Supabase (upsert with field_versions)
///   - Merging incoming remote notes with local state via field-level CRDT
///   - Bootstrap pull of all remote notes
///
/// The CRDT merge logic ensures that if Device A edits the title and
/// Device B edits the body, both edits survive — unlike whole-document
/// LWW where one would be lost.
class SupabaseNoteSyncer {
  SupabaseNoteSyncer({
    required SupabaseClient client,
    required LocalDatabase database,
    required this.userId,
    required HLC clock,
  }) : _client = client,
       _database = database,
       _clock = clock;

  final SupabaseClient _client;
  final LocalDatabase _database;
  final String userId;
  HLC _clock;

  static const String _table = DatabaseConstants.notesTable;

  // ---------------------------------------------------------------------------
  // Push: Local → Supabase
  // ---------------------------------------------------------------------------

  /// Pushes a single sync queue operation to Supabase.
  ///
  /// The operation payload is the serialized Note JSON. We enrich it with
  /// CRDT metadata (user_id, hlc_timestamp, field_versions) before upsert.
  Future<void> pushNote(SyncQueueOperation op) async {
    if (op.payload == null) {
      // Delete operation
      if (op.opType == LocalDatabase.opTypeDelete) {
        await _client
            .from(_table)
            .update({
              DatabaseConstants.isDeleted: true,
              DatabaseConstants.hlcTimestamp: _clock.increment().toString(),
              DatabaseConstants.deletedAt: DateTime.now()
                  .toUtc()
                  .toIso8601String(),
              DatabaseConstants.updatedAt: DateTime.now()
                  .toUtc()
                  .toIso8601String(),
            })
            .eq(DatabaseConstants.id, op.entityId)
            .eq(DatabaseConstants.userId, userId);
        debugPrint('SYNC_PUSH_DELETE_NOTE: ${op.entityId}');
      }
      return;
    }

    final payload = jsonDecode(op.payload!) as Map<String, dynamic>;

    // Read the current field_versions from local DB
    // TODO(impl): Store field_versions in a separate column or in the payload
    final fieldVersions = await _readLocalFieldVersions(op.entityId);

    // Increment the clock for this push
    _clock = _clock.increment();

    // Build the Supabase row
    final row = _notePayloadToRow(payload, fieldVersions);

    await _client.from(_table).upsert(row, onConflict: DatabaseConstants.id);
    debugPrint('SYNC_PUSH_NOTE: ${op.entityId}');
  }

  /// Converts a local Note payload + field versions into a Supabase row.
  Map<String, dynamic> _notePayloadToRow(
    Map<String, dynamic> payload,
    Map<String, String> fieldVersions,
  ) {
    return {
      DatabaseConstants.id: payload['id'],
      DatabaseConstants.userId: userId,
      DatabaseConstants.title: payload['title'] ?? '',
      DatabaseConstants.body: payload['body'],
      'content': payload['body'],
      DatabaseConstants.category: payload['category'] ?? 'personal',
      DatabaseConstants.priority: payload['priority'] ?? 'none',
      DatabaseConstants.isTask:
          payload['isTask'] ?? payload['is_task'] ?? false,
      DatabaseConstants.isAllDay:
          payload['isAllDay'] ?? payload['is_all_day'] ?? false,
      DatabaseConstants.isCompleted:
          payload['isCompleted'] ?? payload['is_completed'] ?? false,
      DatabaseConstants.isRecurringInstance:
          payload['isRecurringInstance'] ??
          payload['is_recurring_instance'] ??
          false,
      DatabaseConstants.isDeleted:
          payload['isDeleted'] ?? payload['is_deleted'] ?? false,
      DatabaseConstants.deletedAt:
          payload['deletedAt'] ?? payload['deleted_at'],
      DatabaseConstants.tags: payload['tags'] ?? [],
      DatabaseConstants.attachments: payload['attachments'] ?? [],
      DatabaseConstants.links: payload['links'] ?? [],
      DatabaseConstants.subtasks: payload['subtasks'] ?? [],
      DatabaseConstants.color: payload['color'],
      DatabaseConstants.order: payload['order'] ?? 0,
      DatabaseConstants.folderId: payload['folderId'] ?? payload['folder_id'],
      DatabaseConstants.parentRecurringId:
          payload['parentRecurringId'] ?? payload['parent_recurring_id'],
      DatabaseConstants.scheduledTime:
          payload['scheduledTime'] ?? payload['scheduled_time'],
      DatabaseConstants.endTime: payload['endTime'] ?? payload['end_time'],
      DatabaseConstants.reminderTime:
          payload['reminderTime'] ?? payload['reminder_time'],
      DatabaseConstants.originalScheduledTime:
          payload['originalScheduledTime'] ??
          payload['original_scheduled_time'],
      DatabaseConstants.completedAt:
          payload['completedAt'] ?? payload['completed_at'],
      DatabaseConstants.recurrenceRule:
          payload['recurrenceRule'] ?? payload['recurrence_rule'],
      DatabaseConstants.deviceLastEdited:
          payload['deviceLastEdited'] ?? payload['device_last_edited'],
      DatabaseConstants.hlcTimestamp: _clock.toString(),
      DatabaseConstants.fieldVersions: fieldVersions,
      DatabaseConstants.updatedAt: DateTime.now().toUtc().toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // Pull / Merge: Supabase → Local
  // ---------------------------------------------------------------------------

  /// Merges a remote note (from Realtime or bootstrap) with local state.
  ///
  /// For each field, the HLC version from field_versions is compared:
  ///   - If remote HLC > local HLC: accept remote value
  ///   - If local HLC >= remote HLC: keep local value
  ///   - If field doesn't exist locally: accept remote value
  Future<void> mergeRemoteNote(Map<String, dynamic> remoteRow) async {
    final noteId = remoteRow['id'] as String;

    // Read local note first. getNote intentionally hides local tombstones, so a
    // null here can mean either "absent" or "already deleted locally".
    final localNote = await _database.getNote(noteId);

    if (_isRemoteDeleted(remoteRow)) {
      final remoteFieldVersions = _parseFieldVersions(
        remoteRow['field_versions'],
      );

      if (localNote == null) {
        await _insertRemoteNote(remoteRow, remoteFieldVersions);
        debugPrint('SYNC_MERGE_NOTE_INSERT_TOMBSTONE: $noteId');
      } else {
        await _database.markNoteDeleted(
          noteId,
          source: SyncWriteSource.remote,
          remoteUpdatedAtMs: _parseRemoteUpdatedAtMs(remoteRow),
        );
        debugPrint('SYNC_MERGE_NOTE_APPLY_TOMBSTONE: $noteId');
      }
      return;
    }

    // Read local field versions for active-note conflict resolution.
    final localFieldVersions = await _readLocalFieldVersions(noteId);

    // Parse remote field versions
    final remoteFieldVersions = _parseFieldVersions(
      remoteRow['field_versions'],
    );

    if (localNote == null) {
      // No local copy — accept remote entirely
      await _insertRemoteNote(remoteRow, remoteFieldVersions);
      debugPrint('SYNC_MERGE_NOTE_INSERT: $noteId');
      return;
    }

    // Perform field-level CRDT merge
    final crdt = FieldLevelCRDT();
    final localMap = _noteToMap(localNote);

    final result = crdt.merge(
      local: localMap,
      localVersions: localFieldVersions,
      remote: _rowToMergeableMap(remoteRow),
      remoteVersions: remoteFieldVersions,
    );

    if (!result.hadConflicts) {
      debugPrint('SYNC_MERGE_NOTE_NO_CHANGE: $noteId');
      return;
    }

    // Write merged result to SQLite (source: remote to avoid re-enqueue)
    await _writeMergedNote(noteId, result);
    debugPrint(
      'SYNC_MERGE_NOTE_MERGED: $noteId '
      '(accepted: ${result.acceptedRemoteFields.join(', ')})',
    );
  }

  /// Pulls all notes for this user from Supabase using as batch upsert and
  /// resumable cursor for performance.
  Future<void> bootstrapNotes() async {
    const pageSize = 500;

    // 1. Read last sync progress
    final cursor = await _database.readCursor('notes');
    String? lastUpdatedAt = cursor.timestampMicros != null
        ? DateTime.fromMicrosecondsSinceEpoch(
            cursor.timestampMicros!,
            isUtc: true,
          ).toIso8601String()
        : null;

    debugPrint('BOOTSTRAP_NOTES: starting from $lastUpdatedAt');

    while (true) {
      var queryBuilder = _client
          .from(_table)
          .select()
          .eq(DatabaseConstants.userId, userId);

      if (lastUpdatedAt != null) {
        // Use gte + lastId to ensure no records are skipped if they share the same timestamp
        queryBuilder = queryBuilder.gte(
          DatabaseConstants.updatedAt,
          lastUpdatedAt,
        );
      }

      var query = queryBuilder
          .order(DatabaseConstants.updatedAt, ascending: true)
          .order(DatabaseConstants.id, ascending: true) // Tie-breaker for pagination
          .limit(pageSize);

      final rows = await query;
      if (rows.isEmpty) break;

      // If we are using gte, we must skip the first record if it matches our cursor exactly
      final cursorId = cursor.lastId;
      final List<Map<String, dynamic>> filteredRows = [];
      for (final row in rows) {
        final rowId = row[DatabaseConstants.id]?.toString();
        final rowUpdatedAt = row[DatabaseConstants.updatedAt]?.toString();
        
        if (rowUpdatedAt == lastUpdatedAt && rowId == cursorId) {
          continue; // Skip the exact record we left off on
        }
        filteredRows.add(row);
      }

      if (filteredRows.isEmpty && rows.isNotEmpty) {
        // We only got the overlap record, and there were no more.
        break;
      }

      // 2. Map rows to Note objects and collect timestamps
      final List<Note> batchNotes = [];
      final Map<String, int> updatedAtMap = {};

      String? batchLastUpdatedAt;
      String? batchLastId;

      for (final row in filteredRows) {
        try {
          final noteJson = _supabaseRowToNoteJson(row);
          final note = Note.fromJson(noteJson);
          batchNotes.add(note);

          final updatedAt =
              row[DatabaseConstants.updatedAt]?.toString() ?? '';
          if (updatedAt.isNotEmpty) {
            updatedAtMap[note.id] = DateTime.parse(
              updatedAt,
            ).millisecondsSinceEpoch;
            batchLastUpdatedAt = updatedAt;
          }
          batchLastId = row[DatabaseConstants.id]?.toString();
        } catch (e) {
          debugPrint(
            'BOOTSTRAP_SKIP_NOTE: ${row[DatabaseConstants.id]}: $e',
          );
          continue; // Skip bad row, don't crash the batch
        }
      }

      // 3. Perform batch upsert
      await _database.batchUpsertNotes(
        batchNotes,
        source: SyncWriteSource.remote,
        remoteUpdatedAtMap: updatedAtMap,
      );

      // 4. Update cursor for resumability
      if (batchLastUpdatedAt != null && batchLastId != null) {
        await _database.writeCursor(
          entityType: 'notes',
          timestampMicros: DateTime.parse(
            batchLastUpdatedAt,
          ).microsecondsSinceEpoch,
          lastId: batchLastId,
        );
        lastUpdatedAt = batchLastUpdatedAt;
      }

      debugPrint('BOOTSTRAP_NOTES: processed batch of ${rows.length}');

      if (rows.length < pageSize) break;
    }

    debugPrint('BOOTSTRAP_NOTES: finished');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Reads field versions from the local SQLite note.
  ///
  /// TODO(impl): Extend the notes table schema to include a `field_versions`
  /// column, then read it here. For the skeleton, returns empty.
  Future<Map<String, String>> _readLocalFieldVersions(String noteId) async {
    // TODO: Read from local DB once the schema is extended
    // final row = await _database.getRawNote(noteId);
    // return _parseFieldVersions(row?['field_versions']);
    return {};
  }

  /// Parses field_versions from Supabase (stored as JSONB).
  Map<String, String> _parseFieldVersions(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      return raw.map(
        (k, v) => MapEntry(_noteFieldFromColumn(k.toString()), v.toString()),
      );
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return decoded.map(
          (k, v) => MapEntry(_noteFieldFromColumn(k), v.toString()),
        );
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  /// Converts a Note to a flat map for merging.
  Map<String, dynamic> _noteToMap(Note note) {
    return note.toJson(); // Uses the freezed-generated toJson
  }

  bool _isRemoteDeleted(Map<String, dynamic> row) {
    return row[DatabaseConstants.isDeleted] == true ||
        row[DatabaseConstants.deletedAt] != null;
  }

  int? _parseRemoteUpdatedAtMs(Map<String, dynamic> row) {
    final value = row[DatabaseConstants.updatedAt];
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch;
    }
    return null;
  }

  /// Converts a Supabase row to a map suitable for merging.
  Map<String, dynamic> _rowToMergeableMap(Map<String, dynamic> row) {
    // Supabase uses snake_case, Note uses camelCase — normalize here
    return {
      'id': row[DatabaseConstants.id],
      'title': row[DatabaseConstants.title],
      'body': row['content'] ?? row[DatabaseConstants.body],
      'category': row[DatabaseConstants.category],
      'priority': row[DatabaseConstants.priority],
      'isTask': _safeBool(row[DatabaseConstants.isTask]),
      'isAllDay': _safeBool(row[DatabaseConstants.isAllDay]),
      'isCompleted': _safeBool(row[DatabaseConstants.isCompleted]),
      'isRecurringInstance': _safeBool(row[DatabaseConstants.isRecurringInstance]),
      'tags': row[DatabaseConstants.tags],
      'attachments': row[DatabaseConstants.attachments],
      'links': row[DatabaseConstants.links],
      'subtasks': row[DatabaseConstants.subtasks],
      'color': row[DatabaseConstants.color],
      'order': row[DatabaseConstants.order],
      'folderId': row[DatabaseConstants.folderId],
      'parentRecurringId':
          row[DatabaseConstants.parentRecurringId],
      'scheduledTime': row[DatabaseConstants.scheduledTime],
      'endTime': row[DatabaseConstants.endTime],
      'reminderTime': row[DatabaseConstants.reminderTime],
      'originalScheduledTime':
          row[DatabaseConstants.originalScheduledTime],
      'completedAt': row[DatabaseConstants.completedAt],
      'recurrenceRule': row[DatabaseConstants.recurrenceRule],
      'deviceLastEdited':
          row[DatabaseConstants.deviceLastEdited],
      'isDeleted': _safeBool(row[DatabaseConstants.isDeleted]),
      'deletedAt': row[DatabaseConstants.deletedAt],
      'updatedAt': row[DatabaseConstants.updatedAt],
    };
  }

  String _noteFieldFromColumn(String key) {
    switch (key) {
      case DatabaseConstants.isTask:
        return 'isTask';
      case DatabaseConstants.isAllDay:
        return 'isAllDay';
      case DatabaseConstants.isCompleted:
        return 'isCompleted';
      case DatabaseConstants.isRecurringInstance:
        return 'isRecurringInstance';
      case DatabaseConstants.folderId:
        return 'folderId';
      case DatabaseConstants.parentRecurringId:
        return 'parentRecurringId';
      case DatabaseConstants.scheduledTime:
        return 'scheduledTime';
      case DatabaseConstants.endTime:
        return 'endTime';
      case DatabaseConstants.reminderTime:
        return 'reminderTime';
      case DatabaseConstants.originalScheduledTime:
        return 'originalScheduledTime';
      case DatabaseConstants.completedAt:
        return 'completedAt';
      case DatabaseConstants.recurrenceRule:
        return 'recurrenceRule';
      case DatabaseConstants.deviceLastEdited:
        return 'deviceLastEdited';
      case DatabaseConstants.isDeleted:
        return 'isDeleted';
      case DatabaseConstants.deletedAt:
        return 'deletedAt';
      case DatabaseConstants.updatedAt:
        return 'updatedAt';
      default:
        return key;
    }
  }

  /// Inserts a remote note into SQLite (no merging, used for new notes).
  Future<void> _insertRemoteNote(
    Map<String, dynamic> row,
    Map<String, String> fieldVersions,
  ) async {
    // Convert Supabase row format to Note JSON format
    final noteJson = _supabaseRowToNoteJson(row);

    await _database.upsertNote(
      Note.fromJson(noteJson),
      source: SyncWriteSource.remote,
      remoteUpdatedAtMs: _parseRemoteUpdatedAtMs(row),
    );
  }

  /// Writes a CRDT-merged note back to SQLite.
  Future<void> _writeMergedNote(String noteId, MergeResult result) async {
    try {
      final note = Note.fromJson(result.mergedData);
      await _database.upsertNote(note, source: SyncWriteSource.remote);
      // TODO: Also persist result.mergedVersions to the field_versions column
    } catch (e) {
      debugPrint('WRITE_MERGED_NOTE_ERROR: $noteId: $e');
    }
  }

  /// Converts a Supabase row (snake_case) to Note JSON (camelCase).
  ///
  /// Notion rule: Never crash on data from the wire.
  /// Every field is treated as potentially null, missing, or wrong type.
  Map<String, dynamic> _supabaseRowToNoteJson(Map<String, dynamic> row) {
    return {
      'id': row[DatabaseConstants.id]?.toString() ?? '',
      'title': row[DatabaseConstants.title] as String? ?? '',
      'body': (row['content'] ?? row[DatabaseConstants.body]) as String?,
      'category': _safeString(row[DatabaseConstants.category], 'personal'),
      'priority': _safeString(row[DatabaseConstants.priority], 'none'),
      'isTask': _safeBool(row[DatabaseConstants.isTask]),
      'isAllDay': _safeBool(row[DatabaseConstants.isAllDay]),
      'isCompleted': _safeBool(row[DatabaseConstants.isCompleted]),
      'isRecurringInstance': _safeBool(row[DatabaseConstants.isRecurringInstance]),
      'tags': _safeStringList(row[DatabaseConstants.tags]),
      'attachments': _safeStringList(row[DatabaseConstants.attachments]),
      'links': _safeStringList(row[DatabaseConstants.links]),
      'subtasks': _safeJsonList(row[DatabaseConstants.subtasks]),
      'color': row[DatabaseConstants.color] is int
          ? row[DatabaseConstants.color]
          : null,
      'order': row[DatabaseConstants.order] is int
          ? row[DatabaseConstants.order]
          : 0,
      'folderId': row[DatabaseConstants.folderId]?.toString(),
      'parentRecurringId':
          row[DatabaseConstants.parentRecurringId]?.toString(),
      'scheduledTime': _safeTimestamp(row[DatabaseConstants.scheduledTime]),
      'endTime': _safeTimestamp(row[DatabaseConstants.endTime]),
      'reminderTime': _safeTimestamp(row[DatabaseConstants.reminderTime]),
      'originalScheduledTime':
          _safeTimestamp(row[DatabaseConstants.originalScheduledTime]),
      'completedAt': _safeTimestamp(row[DatabaseConstants.completedAt]),
      'recurrenceRule': row[DatabaseConstants.recurrenceRule],
      'deviceLastEdited':
          row[DatabaseConstants.deviceLastEdited]?.toString(),
      'updatedAt': _safeTimestamp(row[DatabaseConstants.updatedAt]),
      'isDeleted': _safeBool(row[DatabaseConstants.isDeleted]),
      'deletedAt': _safeTimestamp(row[DatabaseConstants.deletedAt]),
      'createdAt': _safeTimestamp(row[DatabaseConstants.createdAt]) ??
          DateTime.now().toIso8601String(),
    };
  }

  /// Returns true if value is true, 'true', 1, or '1'.
  bool _safeBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final s = value.toLowerCase();
      return s == 'true' || s == '1' || s == 't';
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Safe Parsing Helpers (Notion rule: never throw on wire data)
  // ---------------------------------------------------------------------------

  /// Returns [fallback] when [value] is null or not a String.
  String _safeString(dynamic value, String fallback) {
    if (value is String && value.isNotEmpty) return value;
    return fallback;
  }

  /// Handles both Postgres TEXT[] arrays and JSONB arrays.
  List<String> _safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').toList();
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e?.toString() ?? '').toList();
        }
      } catch (_) {}
    }
    return [];
  }

  /// Handles JSONB arrays (subtasks, etc.) — returns as-is if List,
  /// decodes if String, empty list otherwise.
  List<dynamic> _safeJsonList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return [];
  }

  /// Parses timestamps safely — handles ISO strings, nulls, empty strings.
  String? _safeTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    return null;
  }
}

