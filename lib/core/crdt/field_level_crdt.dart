import 'hlc.dart';

/// Field-Level Last-Write-Wins (LWW) Register backed by HLC timestamps.
///
/// Instead of treating an entire document (Note, Folder) as a single
/// conflict unit, this splits conflict resolution to the individual field
/// level. If Device A edits the title and Device B edits the body,
/// **both edits survive** because each field carries its own HLC version.
///
/// Usage:
/// ```dart
/// final crdt = FieldLevelCRDT();
/// final hlc = clock.increment();
/// crdt.recordWrite('title', hlc);
///
/// // Later, merging with a remote version:
/// final remoteWins = crdt.mergeField('body', remoteHlcString);
/// ```
class FieldLevelCRDT {
  /// Internal map of field name → HLC string for the last write.
  final Map<String, String> _versions;

  /// Creates a new CRDT register, optionally seeded with existing versions.
  FieldLevelCRDT([Map<String, String>? initial])
      : _versions = Map<String, String>.from(initial ?? {});

  /// Returns an unmodifiable view of the current field versions.
  Map<String, String> get versions => Map<String, String>.unmodifiable(_versions);

  /// Records a local write to [field] at the given [clock] time.
  /// Returns the HLC string that was stored.
  String recordWrite(String field, HLC clock) {
    final hlcStr = clock.toString();
    _versions[field] = hlcStr;
    return hlcStr;
  }

  /// Records a local write to multiple [fields] at the given [clock] time.
  /// Each field gets the same HLC — suitable when a single user action
  /// updates several fields atomically (e.g., completing a task sets
  /// `is_completed`, `completed_at`, and `updated_at`).
  Map<String, String> recordBatchWrite(List<String> fields, HLC clock) {
    final hlcStr = clock.toString();
    final result = <String, String>{};
    for (final field in fields) {
      _versions[field] = hlcStr;
      result[field] = hlcStr;
    }
    return result;
  }

  /// Merges a remote field version. Returns `true` if the remote wins
  /// (i.e., the remote HLC is newer than our local version for this field).
  bool mergeField(String field, String remoteHlc) {
    final local = _versions[field];
    if (local == null || _compareVersions(remoteHlc, local) > 0) {
      _versions[field] = remoteHlc;
      return true; // Remote wins — accept remote value
    }
    return false; // Local wins — reject remote value
  }

  /// Given a local entity map and a remote entity map, produces a merged map
  /// where each field is taken from whichever has the newer HLC.
  ///
  /// [identityFields] are never merged (e.g., `id`, `user_id`) — they are
  /// always taken from the local map.
  ///
  /// Returns a [MergeResult] containing the merged data and updated versions.
  MergeResult merge({
    required Map<String, dynamic> local,
    required Map<String, String> localVersions,
    required Map<String, dynamic> remote,
    required Map<String, String> remoteVersions,
    List<String> identityFields = const ['id', 'user_id', 'created_at'],
  }) {
    final merged = Map<String, dynamic>.from(local);
    final mergedVersions = Map<String, String>.from(localVersions);
    final acceptedRemoteFields = <String>[];

    for (final field in remote.keys) {
      if (identityFields.contains(field)) continue;
      if (field == 'field_versions' || field == 'hlc_timestamp') continue;

      final remoteHlc = (remoteVersions[field] == null || remoteVersions[field]!.isEmpty) 
          ? (remote['updatedAt']?.toString() ?? remote['updated_at']?.toString() ?? '') 
          : remoteVersions[field]!;
      final localHlc = (localVersions[field] == null || localVersions[field]!.isEmpty)
          ? (local['updatedAt']?.toString() ?? local['updated_at']?.toString() ?? '')
          : localVersions[field]!;

      if (_compareVersions(remoteHlc, localHlc) > 0 || (remoteHlc.isEmpty && localHlc.isEmpty)) {
        merged[field] = remote[field];
        mergedVersions[field] = remoteHlc;
        acceptedRemoteFields.add(field);
      }
    }

    _versions.addAll(mergedVersions);

    return MergeResult(
      mergedData: merged,
      mergedVersions: mergedVersions,
      acceptedRemoteFields: acceptedRemoteFields,
      hadConflicts: acceptedRemoteFields.isNotEmpty,
    );
  }

  /// Resets internal state. Useful in tests.
  void clear() => _versions.clear();

  int _compareVersions(String left, String right) {
    if (left.isEmpty && right.isEmpty) return 0;
    if (left.isEmpty) return -1;
    if (right.isEmpty) return 1;

    final leftHlc = HLC.tryParse(left);
    final rightHlc = HLC.tryParse(right);
    if (leftHlc != null && rightHlc != null) {
      return leftHlc.compareTo(rightHlc);
    }

    final leftDate = DateTime.tryParse(left);
    final rightDate = DateTime.tryParse(right);
    if (leftDate != null && rightDate != null) {
      return leftDate.compareTo(rightDate);
    }

    return left.compareTo(right);
  }

  @override
  String toString() => 'FieldLevelCRDT(${_versions.length} fields)';
}

/// The result of merging a local and remote entity.
class MergeResult {
  /// The merged data map with winning values for each field.
  final Map<String, dynamic> mergedData;

  /// The merged field version map (HLC string per field).
  final Map<String, String> mergedVersions;

  /// List of field names where the remote value was accepted.
  final List<String> acceptedRemoteFields;

  /// True if at least one field was taken from the remote version.
  final bool hadConflicts;

  const MergeResult({
    required this.mergedData,
    required this.mergedVersions,
    required this.acceptedRemoteFields,
    required this.hadConflicts,
  });

  @override
  String toString() => 'MergeResult(conflicts: $hadConflicts, '
      'accepted: $acceptedRemoteFields)';
}
