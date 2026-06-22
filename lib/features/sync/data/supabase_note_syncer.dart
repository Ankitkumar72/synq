import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart' as quill;
import 'package:markdown_quill/markdown_quill.dart' as md_quill;
import 'package:markdown/markdown.dart' as md;

import 'package:synq/core/crdt/hlc.dart';
import 'package:synq/core/crdt/field_level_crdt.dart';
import 'package:synq/core/database/local_database.dart';
import 'package:synq/features/notes/domain/models/note.dart';
import 'package:synq/core/constants/database_constants.dart';
import 'package:synq/core/utils/document_converter.dart';

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

  // Reusable markdown converter instances
  static final _mdDocument = md.Document(encodeHtml: false);
  static final _mdToDelta = md_quill.MarkdownToDelta(markdownDocument: _mdDocument);
  static final _deltaToMd = md_quill.DeltaToMarkdown();

  static int? _parseColor(dynamic value) {
    if (value == null) return null;
    String colorStr = value.toString().trim();
    if (colorStr.isEmpty) return null;
    if (colorStr.startsWith('#')) {
      colorStr = '0xFF${colorStr.substring(1)}';
    }
    return int.tryParse(colorStr);
  }

  /// Converts a Markdown string to Quill Delta JSON (`List<dynamic>`)
  static List<dynamic>? _markdownToDelta(String? markdown) {
    if (markdown == null || markdown.isEmpty) return null;
    try {
      final delta = _mdToDelta.convert(markdown);
      return delta.toJson();
    } catch (_) {
      return null;
    }
  }

  /// Converts Quill Delta JSON (`List<dynamic>`) to Markdown string
  static String? _deltaToMarkdown(dynamic deltaJson) {
    if (deltaJson == null) return null;
    try {
      final delta = quill.Delta.fromJson(List<Map<String, dynamic>>.from(deltaJson));
      return _deltaToMd.convert(delta);
    } catch (_) {
      return null;
    }
  }

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
        for (final table in [_table, 'tasks', 'events']) {
          await _client
              .from(table)
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
        }
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

    final isTask = payload['isTask'] ?? payload['is_task'] ?? false;
    final isEvent = payload['isEvent'] ?? payload['is_event'] ?? false;
    
    final targetTable = isEvent ? 'events' : (isTask ? 'tasks' : _table);

    // Build the Supabase row
    Map<String, dynamic> row;
    if (isEvent) {
      row = _eventPayloadToRow(payload, fieldVersions);
    } else if (isTask) {
      row = _taskPayloadToRow(payload, fieldVersions);
    } else {
      row = _notePayloadToRow(payload, fieldVersions);
    }

    await _client.from(targetTable).upsert(row, onConflict: DatabaseConstants.id);
    debugPrint('SYNC_PUSH_NOTE ($targetTable): ${op.entityId}');
  }

  /// Converts a local Note payload + field versions into a Supabase row.
  Map<String, dynamic> _notePayloadToRow(
    Map<String, dynamic> payload,
    Map<String, String> fieldVersions,
  ) {
    // payload['body'] is Quill Delta JSON (List<dynamic>)
    final dynamic deltaBody = payload['body'];
    
    // Convert Delta → Markdown for Supabase 'body' column
    String? markdownBody;
    if (deltaBody is List && deltaBody.isNotEmpty) {
      markdownBody = _deltaToMarkdown(deltaBody);
    } else if (deltaBody is String) {
      try {
        final decoded = jsonDecode(deltaBody);
        if (decoded is List) {
          markdownBody = _deltaToMarkdown(decoded);
        }
      } catch (_) {
        markdownBody = deltaBody; // Already plain text/markdown
      }
      
      // Prevent syncing the raw empty delta string if it somehow got into the DB previously
      if (markdownBody != null && 
         (markdownBody.trim() == '{"ops":[{"insert":"\\n"}]}' || 
          markdownBody.trim() == '{"ops":[{"insert":"\\n\\n"}]}')) {
        markdownBody = null;
      }
    }
    
    // Convert Delta → Neutral JSON for Supabase 'content' column
    // DocumentConverter expects a JSON string representation of the Delta
    Map<String, dynamic> contentMap;
    if (deltaBody is List && deltaBody.isNotEmpty) {
      try {
        final deltaJsonStr = jsonEncode(deltaBody);
        contentMap = DocumentConverter.deltaToNeutralJson(deltaJsonStr);
      } catch (_) {
        contentMap = {'type': 'doc', 'content': []};
      }
    } else {
      contentMap = {'type': 'doc', 'content': []};
    }

    return {
      DatabaseConstants.id: payload['id'],
      DatabaseConstants.userId: userId,
      'workspace_id': payload['workspaceId'],
      DatabaseConstants.title: payload['title'] ?? '',
      'content': contentMap,
      'body': markdownBody,
      'version': payload['version'] ?? 1,
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

  Map<String, dynamic> _taskPayloadToRow(
    Map<String, dynamic> payload,
    Map<String, String> fieldVersions,
  ) {
    final isCompleted = payload['isCompleted'] ?? payload['is_completed'] ?? false;
    final scheduledTime = payload['scheduledTime'] ?? payload['scheduled_time'];
    final endTime = payload['endTime'] ?? payload['end_time'];

    // Convert local Quill Delta (stored in payload['body']) to Markdown for Supabase
    final dynamic deltaBody = payload['body'];
    String? markdownBody;
    if (deltaBody is List && deltaBody.isNotEmpty) {
      markdownBody = _deltaToMarkdown(deltaBody);
    } else if (deltaBody is String) {
      // Edge case: body might already be a JSON-encoded string of Delta
      try {
        final decoded = jsonDecode(deltaBody);
        if (decoded is List) {
          markdownBody = _deltaToMarkdown(decoded);
        }
      } catch (_) {
        markdownBody = deltaBody; // Already plain text/markdown
      }
    }

    return {
      'id': payload['id'],
      'user_id': userId,
      'title': payload['title'] ?? '',
      'description': markdownBody ?? payload['body'],
      'body': markdownBody,
      'status': isCompleted ? 'done' : 'todo',
      'priority': payload['priority'] ?? 'none',
      'due_date': scheduledTime,
      'start_at': scheduledTime,
      'end_at': endTime,
      'project_id': payload['folderId'] ?? payload['folder_id'],
      'hlc_timestamp': _clock.toString(),
      'field_versions': fieldVersions,
      'is_deleted': payload['isDeleted'] ?? payload['is_deleted'] ?? false,
      'deleted_at': payload['deletedAt'] ?? payload['deleted_at'],
      'created_at': payload['createdAt'] ?? payload['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'order': payload['order'] ?? 0,
      'recurrence_rule': payload['recurrenceRule'] ?? payload['recurrence_rule'],
      'parent_recurring_id': payload['parentRecurringId'] ?? payload['parent_recurring_id'],
    };
  }

  Map<String, dynamic> _eventPayloadToRow(
    Map<String, dynamic> payload,
    Map<String, String> fieldVersions,
  ) {
    final scheduledTime = payload['scheduledTime'] ?? payload['scheduled_time'] ?? DateTime.now().toUtc().toIso8601String();
    final endTime = payload['endTime'] ?? payload['end_time'] ?? DateTime.now().toUtc().toIso8601String();
    
    // Convert local Quill Delta (stored in payload['body']) to Markdown for Supabase
    final dynamic deltaBody = payload['body'];
    String? markdownBody;
    if (deltaBody is List && deltaBody.isNotEmpty) {
      markdownBody = _deltaToMarkdown(deltaBody);
    } else if (deltaBody is String) {
      // Edge case: body might already be a JSON-encoded string of Delta
      try {
        final decoded = jsonDecode(deltaBody);
        if (decoded is List) {
          markdownBody = _deltaToMarkdown(decoded);
        }
      } catch (_) {
        markdownBody = deltaBody; // Already plain text/markdown
      }
    }

    return {
      'id': payload['id'],
      'user_id': userId,
      'title': payload['title'] ?? '',
      'description': markdownBody ?? payload['body'],
      'body': markdownBody,
      'start_date': scheduledTime,
      'end_date': endTime,
      'color': payload['color']?.toString() ?? '#3b82f6',
      'hlc_timestamp': _clock.toString(),
      'field_versions': fieldVersions,
      'is_deleted': payload['isDeleted'] ?? payload['is_deleted'] ?? false,
      'deleted_at': payload['deletedAt'] ?? payload['deleted_at'],
      'created_at': payload['createdAt'] ?? payload['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
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

  /// Pulls all items (Notes, Tasks, Events) from Supabase and merges them into
  /// the local Note storage. This ensures the mobile app stays in sync with 
  /// the decoupled desktop architecture.
  Future<void> bootstrapNotes() async {
    // 1. Fetch regular Notes
    await _bootstrapTable(table: 'notes', entityType: 'notes');
    
    // 2. Fetch decoupled Tasks
    await _bootstrapTable(
      table: 'tasks', 
      entityType: 'tasks_as_notes',
      mapper: taskRowToNoteJson,
    );
    
    // 3. Fetch decoupled Events
    await _bootstrapTable(
      table: 'events', 
      entityType: 'events_as_notes',
      mapper: eventRowToNoteJson,
    );
  }

  /// Internal helper for paginated bootstrap of any table.
  Future<void> _bootstrapTable({
    required String table,
    required String entityType,
    Map<String, dynamic> Function(Map<String, dynamic>)? mapper,
  }) async {
    const pageSize = 500;
    final cursor = await _database.readCursor(entityType);
    String? lastUpdatedAt = cursor.timestampMicros != null
        ? DateTime.fromMicrosecondsSinceEpoch(
            cursor.timestampMicros!,
            isUtc: true,
          ).toIso8601String()
        : null;

    debugPrint('BOOTSTRAP_$table: starting from $lastUpdatedAt');

    while (true) {
      var queryBuilder = _client
          .from(table)
          .select()
          .eq(DatabaseConstants.userId, userId);

      if (lastUpdatedAt != null) {
        queryBuilder = queryBuilder.gte(DatabaseConstants.updatedAt, lastUpdatedAt);
      }

      final rows = await queryBuilder
          .order(DatabaseConstants.updatedAt, ascending: true)
          .order(DatabaseConstants.id, ascending: true)
          .limit(pageSize);

      if (rows.isEmpty) break;

      final cursorId = cursor.lastId;
      final List<Map<String, dynamic>> filteredRows = [];
      for (final row in rows) {
        final rowId = row['id']?.toString();
        final rowUpdatedAt = row[DatabaseConstants.updatedAt]?.toString();
        if (rowUpdatedAt == lastUpdatedAt && rowId == cursorId) continue;
        filteredRows.add(row);
      }

      if (filteredRows.isEmpty) break;

      final List<Note> batchNotes = [];
      final Map<String, int> updatedAtMap = {};
      String? batchLastUpdatedAt;
      String? batchLastId;

      for (final row in filteredRows) {
        try {
          // Map to Note JSON via the provided mapper or default note mapper
          final noteJson = mapper != null 
              ? mapper(row) 
              : _supabaseRowToNoteJson(row);
          
          final note = Note.fromJson(noteJson);
          batchNotes.add(note);

          final updatedAt = row[DatabaseConstants.updatedAt]?.toString() ?? '';
          if (updatedAt.isNotEmpty) {
            updatedAtMap[note.id] = DateTime.parse(updatedAt).millisecondsSinceEpoch;
            batchLastUpdatedAt = updatedAt;
          }
          batchLastId = row['id']?.toString();
        } catch (e) {
          debugPrint('BOOTSTRAP_SKIP_$table: ${row['id']}: $e');
          continue;
        }
      }

      await _database.batchUpsertNotes(
        batchNotes,
        source: SyncWriteSource.remote,
        remoteUpdatedAtMap: updatedAtMap,
      );

      if (batchLastUpdatedAt != null && batchLastId != null) {
        await _database.writeCursor(
          entityType: entityType,
          timestampMicros: DateTime.parse(batchLastUpdatedAt).microsecondsSinceEpoch,
          lastId: batchLastId,
        );
        lastUpdatedAt = batchLastUpdatedAt;
      }

      if (rows.length < pageSize) break;
    }
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
    // Handle content mapping
    String? bodyStr;
    if (row['content'] != null) {
      if (row['content'] is Map) {
        bodyStr = DocumentConverter.neutralJsonToDelta(row['content'] as Map<String, dynamic>);
      } else if (row['content'] is String) {
        try {
          bodyStr = DocumentConverter.neutralJsonToDelta(jsonDecode(row['content']));
        } catch (_) {
          bodyStr = row['content'];
        }
      }
    } else {
      bodyStr = row[DatabaseConstants.body] as String?;
    }

    return {
      'id': row[DatabaseConstants.id],
      'workspaceId': row['workspace_id'],
      'title': row[DatabaseConstants.title],
      'body': bodyStr,
      'version': row['version'] ?? 1,
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

  /// Converts a Task row from the tasks table to Note JSON format.
  Map<String, dynamic> taskRowToNoteJson(Map<String, dynamic> row) {
    final Map<String, dynamic> json = Map.from(row);
    
    final String? bodyMarkdown = row['body']?.toString();
    if (bodyMarkdown != null && bodyMarkdown.isNotEmpty) {
      final delta = _markdownToDelta(bodyMarkdown);
      if (delta != null) {
        json['body'] = delta;
      }
    }

    return {
      'id': json['id']?.toString() ?? '',
      'title': json['title'] as String? ?? '',
      'body': json['body'] != null ? jsonEncode(json['body']) : json['description'] as String?,
      'category': _safeString(json['category'], 'personal'),
      'priority': _safeString(row['priority'], 'none'),
      'isTask': true,
      'isEvent': false,
      'isAllDay': false,
      'isCompleted': row['status'] == 'done',
      'scheduledTime': _safeTimestamp(row['start_at'] ?? row['due_date']),
      'endTime': _safeTimestamp(row['end_at']),
      'hlcTimestamp': row['hlc_timestamp']?.toString(),
      'fieldVersions': row['field_versions'],
      'isDeleted': _safeBool(row['is_deleted']),
      'deletedAt': _safeTimestamp(row['deleted_at']),
      'updatedAt': _safeTimestamp(row['updated_at']),
      'createdAt': _safeTimestamp(row['created_at']) ?? DateTime.now().toIso8601String(),
      // Preserved for syncer internal checks (_isRemoteDeleted, etc)
      'is_deleted': _safeBool(row['is_deleted']),
      'deleted_at': _safeTimestamp(row['deleted_at']),
      'updated_at': _safeTimestamp(row['updated_at']),
      'device_last_edited': row['device_last_edited']?.toString(),
    };
  }


  /// Converts an Event row from the events table to Note JSON format.
  Map<String, dynamic> eventRowToNoteJson(Map<String, dynamic> row) {
    final Map<String, dynamic> json = Map.from(row);
    
    final String? bodyMarkdown = row['body']?.toString();
    if (bodyMarkdown != null && bodyMarkdown.isNotEmpty) {
      final delta = _markdownToDelta(bodyMarkdown);
      if (delta != null) {
        json['body'] = delta;
      }
    }

    return {
      'id': json['id']?.toString() ?? '',
      'title': json['title'] as String? ?? '',
      'body': json['body'] != null ? jsonEncode(json['body']) : json['description'] as String?,
      'isTask': false,
      'isEvent': true,
      'isAllDay': false,
      'scheduledTime': _safeTimestamp(json['start_date']),
      'endTime': _safeTimestamp(json['end_date']),
      'color': json['color'] is int
          ? json['color']
          : _parseColor(json['color']),
      'hlcTimestamp': row['hlc_timestamp']?.toString(),
      'fieldVersions': row['field_versions'],
      'isDeleted': _safeBool(row['is_deleted']),
      'deletedAt': _safeTimestamp(row['deleted_at']),
      'updatedAt': _safeTimestamp(row['updated_at']),
      'createdAt': _safeTimestamp(row['created_at']) ?? DateTime.now().toIso8601String(),
      // Preserved for syncer internal checks (_isRemoteDeleted, etc)
      'is_deleted': _safeBool(row['is_deleted']),
      'deleted_at': _safeTimestamp(row['deleted_at']),
      'updated_at': _safeTimestamp(row['updated_at']),
      'device_last_edited': row['device_last_edited']?.toString(),
    };
  }


  /// Converts a Supabase row (snake_case) to Note JSON (camelCase).
  ///
  /// Notion rule: Never crash on data from the wire.
  /// Every field is treated as potentially null, missing, or wrong type.
  Map<String, dynamic> _supabaseRowToNoteJson(Map<String, dynamic> row) {
    final Map<String, dynamic> json = Map.from(row);
    
    final String? bodyMarkdown = row['body']?.toString();
    if (bodyMarkdown != null && bodyMarkdown.isNotEmpty) {
      final delta = _markdownToDelta(bodyMarkdown);
      if (delta != null) {
        json['body'] = delta;
      }
    }

    String? bodyStr;
    if (json['content'] != null) {
      if (json['content'] is Map) {
        bodyStr = DocumentConverter.neutralJsonToDelta(row['content'] as Map<String, dynamic>);
      } else if (row['content'] is String) {
        try {
          bodyStr = DocumentConverter.neutralJsonToDelta(jsonDecode(json['content']));
        } catch (_) {
          bodyStr = json['content'];
        }
      }
    } else {
      bodyStr = json[DatabaseConstants.body] as String?;
    }

    return {
      'id': json[DatabaseConstants.id]?.toString() ?? '',
      'workspaceId': json['workspace_id']?.toString(),
      'title': json[DatabaseConstants.title] as String? ?? '',
      'body': json['body'] != null ? jsonEncode(json['body']) : bodyStr,
      'version': json['version'] ?? 1,
      'category': _safeString(json[DatabaseConstants.category], 'personal'),
      'priority': _safeString(json[DatabaseConstants.priority], 'none'),
      'isTask': _safeBool(json[DatabaseConstants.isTask]),
      'isEvent': false,
      'isAllDay': _safeBool(json[DatabaseConstants.isAllDay]),
      'isCompleted': _safeBool(json[DatabaseConstants.isCompleted]),
      'isRecurringInstance': _safeBool(json[DatabaseConstants.isRecurringInstance]),
      'tags': _safeStringList(json[DatabaseConstants.tags]),
      'attachments': _safeStringList(json[DatabaseConstants.attachments]),
      'links': _safeStringList(json[DatabaseConstants.links]),
      'subtasks': _safeJsonList(json[DatabaseConstants.subtasks]),
      'color': json[DatabaseConstants.color] is int
          ? json[DatabaseConstants.color]
          : null,
      'order': json[DatabaseConstants.order] is int
          ? json[DatabaseConstants.order]
          : 0,
      'folderId': json[DatabaseConstants.folderId]?.toString(),
      'parentRecurringId':
          json[DatabaseConstants.parentRecurringId]?.toString(),
      'scheduledTime': _safeTimestamp(json[DatabaseConstants.scheduledTime]),
      'endTime': _safeTimestamp(json[DatabaseConstants.endTime]),
      'reminderTime': _safeTimestamp(json[DatabaseConstants.reminderTime]),
      'originalScheduledTime':
          _safeTimestamp(json[DatabaseConstants.originalScheduledTime]),
      'completedAt': _safeTimestamp(json[DatabaseConstants.completedAt]),
      'recurrenceRule': json[DatabaseConstants.recurrenceRule],
      'deviceLastEdited':
          json[DatabaseConstants.deviceLastEdited]?.toString(),
      'updatedAt': _safeTimestamp(json[DatabaseConstants.updatedAt]),
      'isDeleted': _safeBool(json[DatabaseConstants.isDeleted]),
      'deletedAt': _safeTimestamp(json[DatabaseConstants.deletedAt]),
      'createdAt': _safeTimestamp(json[DatabaseConstants.createdAt]) ??
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

