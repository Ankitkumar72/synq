import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../features/notes/domain/models/note.dart' show NoteCategory;

part 'activity_event.freezed.dart';
part 'activity_event.g.dart';

enum ActivityEventType {
  @JsonValue('COMPLETED')
  completed,
  @JsonValue('UNCOMPLETED')
  uncompleted,
}

@freezed
class ActivityEvent with _$ActivityEvent {
  const factory ActivityEvent({
    required String id,
    required String taskId,
    required ActivityEventType type,
    required DateTime timestamp,
    required NoteCategory category,
  }) = _ActivityEvent;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) => _$ActivityEventFromJson(json);
}
