import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/crdt/hlc.dart';
import '../../../core/crdt/field_level_crdt.dart';
import '../../../core/database/local_database.dart';
import '../../folders/domain/models/folder.dart';

/// Handles folder-specific sync operations between local SQLite and Supabase.
///
/// Mirrors [SupabaseNoteSyncer] but for the `folders` table.
/// Supports field-level CRDT merging for folder attributes (name, color, icon, etc.).
class SupabaseFolderSyncer {
  SupabaseFolderSyncer({
    required SupabaseClient client,
    required LocalDatabase database,
    required this.userId,
    required HLC clock,
  })  : _client = client,
        _database = database,
        _clock = clock;

  final SupabaseClient _client;
  final LocalDatabase _database;
  final String userId;
  HLC _clock;

  static const String _table = 'folders';

  // ---------------------------------------------------------------------------
  // Push: Local → Supabase
  // ---------------------------------------------------------------------------

  /// Pushes a single folder sync queue operation to Supabase.
  Future<void> pushFolder(SyncQueueOperation op) async {
    if (op.payload == null) {
      if (op.opType == LocalDatabase.opTypeDelete) {
        await _client
            .from(_table)
            .update({
              'is_deleted': true,
              'deleted_at': DateTime.now().toUtc().toIso8601String(),
              'hlc_timestamp': _clock.increment().toString(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', op.entityId)
            .eq('user_id', userId);
        debugPrint('SYNC_PUSH_DELETE_FOLDER: ${op.entityId}');
      }
      return;
    }

    final payload = jsonDecode(op.payload!) as Map<String, dynamic>;
    final fieldVersions = await _readLocalFieldVersions(op.entityId);

    _clock = _clock.increment();

    final row = _folderPayloadToRow(payload, fieldVersions);
    await _client.from(_table).upsert(row, onConflict: 'id');
    debugPrint('SYNC_PUSH_FOLDER: ${op.entityId}');
  }

  Map<String, dynamic> _folderPayloadToRow(
    Map<String, dynamic> payload,
    Map<String, String> fieldVersions,
  ) {
    return {
      'id': payload['id'],
      'user_id': userId,
      'name': payload['name'] ?? '',
      'icon_code_point': payload['iconCodePoint'] ?? payload['icon_code_point'] ?? 0xe88a,
      'color': payload['colorValue'] ?? payload['color_value'] ?? 0xFF2196F3,
      'is_favorite': payload['isFavorite'] ?? payload['is_favorite'] ?? false,
      'is_deleted': false,
      'parent_id': payload['parentId'] ?? payload['parent_id'],
      // CRDT fields
      'hlc_timestamp': _clock.toString(),
      'field_versions': fieldVersions,
      'created_at': payload['createdAt'] ??
          payload['created_at'] ??
          DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // Pull / Merge: Supabase → Local
  // ---------------------------------------------------------------------------

  /// Merges a remote folder with local state via field-level CRDT.
  Future<void> mergeRemoteFolder(Map<String, dynamic> remoteRow) async {
    final folderId = remoteRow['id'] as String;

    // Handle remote deletions first (mirrors SupabaseNoteSyncer pattern)
    if (remoteRow['is_deleted'] == true || remoteRow['deleted_at'] != null) {
      final localFolder = await _database.getFolder(folderId);
      if (localFolder != null) {
        final updatedAtMs = _parseRemoteUpdatedAtMs(remoteRow);
        await _database.markFolderDeleted(
          folderId,
          source: SyncWriteSource.remote,
          remoteUpdatedAtMs: updatedAtMs,
        );
        debugPrint('SYNC_MERGE_FOLDER_APPLY_TOMBSTONE: $folderId');
      } else {
        // Already deleted or unknown — just ensure it's tombstoned locally
        final updatedAtMs = _parseRemoteUpdatedAtMs(remoteRow);
        await _database.markFolderDeleted(
          folderId,
          source: SyncWriteSource.remote,
          remoteUpdatedAtMs: updatedAtMs,
        );
        debugPrint('SYNC_MERGE_FOLDER_INSERT_TOMBSTONE: $folderId');
      }
      return;
    }

    final localFolder = await _database.getFolder(folderId);
    final localFieldVersions = await _readLocalFieldVersions(folderId);
    final remoteFieldVersions = _parseFieldVersions(remoteRow['field_versions']);

    if (localFolder == null) {
      await _insertRemoteFolder(remoteRow, remoteFieldVersions);
      debugPrint('SYNC_MERGE_FOLDER_INSERT: $folderId');
      return;
    }

    final crdt = FieldLevelCRDT();
    final localMap = _folderToMap(localFolder);

    final result = crdt.merge(
      local: localMap,
      localVersions: localFieldVersions,
      remote: _rowToMergeableMap(remoteRow),
      remoteVersions: remoteFieldVersions,
    );

    if (!result.hadConflicts) {
      debugPrint('SYNC_MERGE_FOLDER_NO_CHANGE: $folderId');
      return;
    }

    await _writeMergedFolder(folderId, result);
    debugPrint('SYNC_MERGE_FOLDER_MERGED: $folderId '
        '(accepted: ${result.acceptedRemoteFields.join(', ')})');
  }

  /// Pulls all folders for this user from Supabase using batch upsert and 
  /// resumable cursor for performance.
  Future<void> bootstrapFolders() async {
    const pageSize = 500;
    
    // 1. Read last sync progress
    final cursor = await _database.readCursor('folders');
    String? lastUpdatedAt = cursor.timestampMicros != null 
        ? DateTime.fromMicrosecondsSinceEpoch(cursor.timestampMicros!, isUtc: true).toIso8601String()
        : null;

    debugPrint('BOOTSTRAP_FOLDERS: starting from $lastUpdatedAt');

    while (true) {
      var queryBuilder = _client
          .from(_table)
          .select()
          .eq('user_id', userId);

      if (lastUpdatedAt != null) {
        queryBuilder = queryBuilder.gte('updated_at', lastUpdatedAt);
      }

      var query = queryBuilder
          .order('updated_at', ascending: true)
          .order('id', ascending: true)
          .limit(pageSize);

      final rows = await query;
      if (rows.isEmpty) break;

      // Filter out overlapping records from previous batch
      final cursorId = cursor.lastId;
      final List<Map<String, dynamic>> filteredRows = [];
      for (final row in rows) {
        final rowId = row['id']?.toString();
        final rowUpdatedAt = row['updated_at']?.toString();
        
        if (rowUpdatedAt == lastUpdatedAt && rowId == cursorId) {
          continue; 
        }
        filteredRows.add(row);
      }

      if (filteredRows.isEmpty && rows.isNotEmpty) {
        break;
      }

      // 2. Map rows to Folder objects, split active vs deleted
      final List<Folder> activeFolders = [];
      final Map<String, int> updatedAtMap = {};
      final List<Map<String, dynamic>> deletedRows = [];
      
      String? batchLastUpdatedAt;
      String? batchLastId;

      for (final row in filteredRows) {
        try {
          final updatedAt = row['updated_at']?.toString() ?? '';
          final updatedAtMs = updatedAt.isNotEmpty
              ? DateTime.parse(updatedAt).millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch;

          batchLastUpdatedAt = updatedAt.isNotEmpty ? updatedAt : null;
          batchLastId = row['id']?.toString();

          // Route deleted folders through markFolderDeleted
          if (row['is_deleted'] == true) {
            deletedRows.add(row);
            continue;
          }

          final folderJson = _supabaseRowToFolderJson(row);
          final folder = Folder.fromJson(folderJson);
          activeFolders.add(folder);
          updatedAtMap[folder.id] = updatedAtMs;
        } catch (e) {
          debugPrint(
            'BOOTSTRAP_SKIP_FOLDER: ${row['id']}: $e',
          );
          continue;
        }
      }

      // 3a. Upsert active folders
      if (activeFolders.isNotEmpty) {
        await _database.batchUpsertFolders(
          activeFolders,
          source: SyncWriteSource.remote,
          remoteUpdatedAtMap: updatedAtMap,
        );
      }

      // 3b. Mark deleted folders as deleted locally
      for (final row in deletedRows) {
        final folderId = row['id'] as String;
        final updatedAt = row['updated_at'] as String;
        await _database.markFolderDeleted(
          folderId,
          source: SyncWriteSource.remote,
          remoteUpdatedAtMs: DateTime.parse(updatedAt).millisecondsSinceEpoch,
        );
      }

      // 4. Update cursor for resumability
      if (batchLastUpdatedAt != null && batchLastId != null) {
        await _database.writeCursor(
          entityType: 'folders',
          timestampMicros: DateTime.parse(batchLastUpdatedAt).microsecondsSinceEpoch,
          lastId: batchLastId,
        );
        lastUpdatedAt = batchLastUpdatedAt;
      }

      debugPrint('BOOTSTRAP_FOLDERS: processed batch of ${rows.length}');

      if (rows.length < pageSize) break;
    }
    
    debugPrint('BOOTSTRAP_FOLDERS: finished');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _readLocalFieldVersions(String folderId) async {
    // TODO: Read from local DB once schema is extended
    return {};
  }

  int? _parseRemoteUpdatedAtMs(Map<String, dynamic> row) {
    final value = row['updated_at'];
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch;
    }
    return null;
  }

  Map<String, String> _parseFieldVersions(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  Map<String, dynamic> _folderToMap(Folder folder) {
    return folder.toJson();
  }

  Map<String, dynamic> _rowToMergeableMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'icon_code_point': row['icon_code_point'],
      'color': row['color'],
      'is_favorite': row['is_favorite'],
      'is_deleted': row['is_deleted'],
      'parent_id': row['parent_id'],
    };
  }

  Future<void> _insertRemoteFolder(
    Map<String, dynamic> row,
    Map<String, String> fieldVersions,
  ) async {
    final folderJson = _supabaseRowToFolderJson(row);
    try {
      final folder = Folder.fromJson(folderJson);
      await _database.upsertFolder(folder, source: SyncWriteSource.remote);
    } catch (e) {
      debugPrint('INSERT_REMOTE_FOLDER_ERROR: ${row['id']}: $e');
    }
  }

  Future<void> _writeMergedFolder(String folderId, MergeResult result) async {
    try {
      final folder = Folder.fromJson(result.mergedData);
      await _database.upsertFolder(folder, source: SyncWriteSource.remote);
      // TODO: Also persist result.mergedVersions
    } catch (e) {
      debugPrint('WRITE_MERGED_FOLDER_ERROR: $folderId: $e');
    }
  }

  Map<String, dynamic> _supabaseRowToFolderJson(Map<String, dynamic> row) {
    return {
      'id': row['id']?.toString() ?? '',
      'name': row['name'] as String? ?? '',
      'iconCodePoint': row['icon_code_point'] is int
          ? row['icon_code_point']
          : 0xe88a,
      'iconFontFamily': row['icon_font_family'] as String?,
      'colorValue': _safeFolderColor(row['color'] ?? row['color_value']),
      'isFavorite': row['is_favorite'] == true,
      'parentId': row['parent_id']?.toString(),
      'createdAt': (row['created_at'] as String?) ??
          DateTime.now().toIso8601String(),
    };
  }

  /// Safely parse folder color — handles int, null, and invalid types.
  int _safeFolderColor(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0xFF2196F3;
    }
    return 0xFF2196F3; // Default Material Blue
  }
}
