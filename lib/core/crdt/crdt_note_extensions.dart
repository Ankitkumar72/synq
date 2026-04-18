import '../../features/notes/domain/models/note.dart';
import '../../features/folders/domain/models/folder.dart';
import 'hlc.dart';
import 'field_level_crdt.dart';

/// Extension methods that bridge the Note/Folder domain models with
/// the CRDT merge engine.
///
/// These convert domain objects to/from flat maps suitable for
/// field-level merging and Supabase row format.

/// List of all mergeable note fields (excludes identity fields).
const kNoteFields = [
  'title',
  'body',
  'category',
  'priority',
  'is_task',
  'is_all_day',
  'is_completed',
  'is_recurring_instance',
  'is_deleted',
  'tags',
  'attachments',
  'links',
  'subtasks',
  'color',
  'order',
  'folder_id',
  'parent_recurring_id',
  'scheduled_time',
  'end_time',
  'reminder_time',
  'original_scheduled_time',
  'completed_at',
  'recurrence_rule',
  'device_last_edited',
  'updated_at',
];

/// List of all mergeable folder fields.
const kFolderFields = [
  'name',
  'icon_code_point',
  'color_value',
  'is_favorite',
  'is_deleted',
  'parent_id',
];

extension NoteFieldMap on Note {
  /// Converts a Note to a flat field map suitable for CRDT merging
  /// and Supabase row format.
  Map<String, dynamic> toCrdtMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'category': category.name,
      'priority': priority.name,
      'is_task': isTask,
      'is_all_day': isAllDay,
      'is_completed': isCompleted,
      'is_recurring_instance': isRecurringInstance,
      'tags': tags,
      'attachments': attachments,
      'links': links,
      'subtasks': subtasks.map((s) => s.toJson()).toList(),
      'color': color,
      'order': order,
      'folder_id': folderId,
      'parent_recurring_id': parentRecurringId,
      'scheduled_time': scheduledTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'reminder_time': reminderTime?.toIso8601String(),
      'original_scheduled_time': originalScheduledTime?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'recurrence_rule': recurrenceRule?.toJson(),
      'device_last_edited': deviceLastEdited,
      'updated_at': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

extension FolderFieldMap on Folder {
  /// Converts a Folder to a flat field map suitable for CRDT merging
  /// and Supabase row format.
  Map<String, dynamic> toCrdtMap() {
    return {
      'id': id,
      'name': name,
      'icon_code_point': iconCodePoint,
      'color_value': colorValue,
      'is_favorite': isFavorite,
      'parent_id': parentId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Helper to stamp all edited fields with the current HLC.
///
/// Usage:
/// ```dart
/// final clock = HLC.now(deviceId);
/// final versions = stampEditedFields(
///   editedFields: ['title', 'body'],
///   clock: clock,
///   existingVersions: note.fieldVersions,
/// );
/// ```
Map<String, String> stampEditedFields({
  required List<String> editedFields,
  required HLC clock,
  Map<String, String> existingVersions = const {},
}) {
  final crdt = FieldLevelCRDT(existingVersions);
  crdt.recordBatchWrite(editedFields, clock);
  return crdt.versions;
}
