import 'package:freezed_annotation/freezed_annotation.dart';

part 'note.freezed.dart';
part 'note.g.dart';

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
    DateTime? scheduledTime,
    DateTime? endTime,
    DateTime? completedAt,
    @Default(TaskPriority.medium) TaskPriority priority,
    @Default(false) bool isTask, // true = task, false = note
    @Default(false) bool isCompleted,
    @Default([]) List<String> tags,
    @Default([]) List<String> attachments, // URLs of uploaded images/media
    @Default([]) List<String> links, // Embedded URLs
  }) = _Note;

  const Note._();

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);

  // Duration helper
  Duration? get duration => 
    (scheduledTime != null && endTime != null) 
      ? endTime!.difference(scheduledTime!) 
      : null;
      
  // Is happening now?
  bool get isActive {
    if (scheduledTime == null || endTime == null) return false;
    final now = DateTime.now();
    return now.isAfter(scheduledTime!) && now.isBefore(endTime!);
  }
  
  // Is upcoming (within next hour)?
  bool get isUpcoming {
    if (scheduledTime == null) return false;
    final now = DateTime.now();
    return scheduledTime!.isAfter(now) && 
           scheduledTime!.isBefore(now.add(const Duration(hours: 1)));
  }
}
