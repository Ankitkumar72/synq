// import '../models/task.dart'; // No longer needed as we're independent
import 'package:freezed_annotation/freezed_annotation.dart';

part 'timeline_event.freezed.dart';

enum TimelineEventType { strategy, active, rest, standard, admin, design }

@freezed
class TimelineEvent with _$TimelineEvent {
  const factory TimelineEvent({
    required String id,
    required String title,
    required String startTime,
    required String endTime,
    required TimelineEventType type,
    String? subtitle,
    String? tag,
    String? category, // E.g., "Personal", "Work"
    @Default(false) bool isCompleted,
    @Default(false) bool isCurrent,
  }) = _TimelineEvent;
}
