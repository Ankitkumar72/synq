import 'package:freezed_annotation/freezed_annotation.dart';
import 'recurrence_rule.dart'; 

part 'note.freezed.dart';
part 'note.g.dart';

/// Category for notes and tasks
enum NoteCategory { work, personal, idea }


enum TaskPriority { low, medium, high }

@freezed
class SubTask with _$SubTask {
  const factory SubTask({
    required String id,
    required String title,
    @Default(false) bool isCompleted,
  }) = _SubTask;

  factory SubTask.fromJson(Map<String, dynamic> json) => _$SubTaskFromJson(json);
}

@freezed
class Note with _$Note {

  const Note._();

  const factory Note({
    required String id,
    required String title,
    String? body,
    required NoteCategory category,
    required DateTime createdAt,
    DateTime? scheduledTime,
    DateTime? endTime,
    DateTime? reminderTime,
    RecurrenceRule? recurrenceRule, 
    String? parentRecurringId, 
    DateTime? originalScheduledTime, 
    DateTime? completedAt,
    @Default(TaskPriority.medium) TaskPriority priority,
    @Default(false) bool isTask, 
    @Default(false) bool isAllDay, 
    @Default(false) bool isRecurringInstance, 
    @Default(false) bool isCompleted,
    @Default([]) List<String> tags,
    @Default([]) List<String> attachments, 
    @Default([]) List<String> links, 
    @Default([]) List<SubTask> subtasks, 
    String? folderId, 
    DateTime? updatedAt, 
  }) = _Note;

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);

  Duration? get duration => 
    (scheduledTime != null && endTime != null) 
      ? endTime!.difference(scheduledTime!) 
      : null;
      
  /// Checks if the task is currently happening (Now is between Start and End)
  bool get isActive {
    if (scheduledTime == null || endTime == null) return false;
    final now = DateTime.now();
    return now.isAfter(scheduledTime!) && now.isBefore(endTime!);
  }
  
  /// Checks if the task is starting within the next hour
  bool get isUpcoming {
    if (scheduledTime == null) return false;
    final now = DateTime.now();
    return scheduledTime!.isAfter(now) && 
           scheduledTime!.isBefore(now.add(const Duration(hours: 1)));
  }
}