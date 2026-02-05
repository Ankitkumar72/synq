import 'package:freezed_annotation/freezed_annotation.dart';

part 'note.freezed.dart';

/// Category for notes and tasks
enum NoteCategory { work, personal, idea }

/// Priority level for tasks
enum TaskPriority { low, medium, high }

/// Represents a note or task created by the user
@freezed
class Note with _$Note {
  const factory Note({
    required String id,
    required String title,
    String? body,
    required NoteCategory category,
    required DateTime createdAt,
    DateTime? dueDate,
    @Default(TaskPriority.medium) TaskPriority priority,
    @Default(false) bool isTask, // true = task, false = note
    @Default(false) bool isCompleted,
    @Default([]) List<String> tags,
  }) = _Note;
}
