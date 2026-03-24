import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../notes/domain/models/note.dart' show NoteCategory, SubTask, TaskPriority;
import '../../../../core/domain/models/recurrence_rule.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@freezed
class Task with _$Task {
  const Task._();

  // ignore: invalid_annotation_target
  @JsonSerializable(explicitToJson: true)
  const factory Task({
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
    @Default(TaskPriority.none) TaskPriority priority,
    @Default(true) bool isTask,
    @Default(false) bool isAllDay,
    @Default(false) bool isRecurringInstance,
    @Default(false) bool isCompleted,
    @Default([]) List<String> tags,
    @Default([]) List<String> attachments,
    @Default([]) List<String> links,
    @Default([]) List<SubTask> subtasks,
    String? folderId,
    DateTime? updatedAt,
    String? deviceLastEdited,
    int? color,
    @Default(0) int order,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  Duration? get duration => (scheduledTime != null && endTime != null)
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
