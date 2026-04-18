class DatabaseConstants {
  // Tables
  static const String notesTable = 'notes';
  static const String foldersTable = 'folders';
  static const String tasksTable = 'tasks';
  static const String devicesTable = 'devices';
  static const String noteContentWebTable = 'note_content_web';

  // Columns
  static const String id = 'id';
  static const String userId = 'user_id';
  static const String title = 'title';
  static const String body = 'body';
  static const String category = 'category';
  static const String priority = 'priority';
  static const String isTask = 'is_task';
  static const String isAllDay = 'is_all_day';
  static const String isCompleted = 'is_completed';
  static const String isRecurringInstance = 'is_recurring_instance';
  static const String isDeleted = 'is_deleted';
  static const String deletedAt = 'deleted_at';
  static const String tags = 'tags';
  static const String attachments = 'attachments';
  static const String links = 'links';
  static const String subtasks = 'subtasks';
  static const String color = 'color';
  static const String order = 'order';
  static const String folderId = 'folder_id';
  static const String parentRecurringId = 'parent_recurring_id';
  static const String scheduledTime = 'scheduled_time';
  static const String endTime = 'end_time';
  static const String reminderTime = 'reminder_time';
  static const String originalScheduledTime = 'original_scheduled_time';
  static const String completedAt = 'completed_at';
  static const String recurrenceRule = 'recurrence_rule';
  static const String deviceLastEdited = 'device_last_edited';
  
  // CRDT specific
  static const String hlcTimestamp = 'hlc_timestamp';
  static const String fieldVersions = 'field_versions';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
}
