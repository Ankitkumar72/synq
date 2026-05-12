import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'timeline_event.freezed.dart';

enum TimelineEventType { strategy, active, rest, standard, admin, design }

/// Distinguishes tasks (rendered as chips) from events (rendered as blocks).
enum EventKind { event, task, taskGroup }

@freezed
class TimelineEvent with _$TimelineEvent {
  const factory TimelineEvent({
    required String id,
    required String title,
    required String startTime,
    required String endTime,
    required TimelineEventType type,
    @Default(EventKind.event) EventKind kind,
    String? subtitle,
    String? tag,
    String? category, // E.g., "Personal", "Work"
    @Default(false) bool isCompleted,
    @Default(false) bool isCurrent,
    int? color,
    List<TimelineEvent>? groupedTasks,
  }) = _TimelineEvent;

  const TimelineEvent._();

  int get startMinutes => parseMinutes(startTime);
  int get endMinutes => parseMinutes(endTime);
  int get durationMinutes {
    final diff = endMinutes - startMinutes;
    return diff <= 0 ? 15 : diff;
  }

  static int parseMinutes(String timeStr) {
    try {
      final cleanTime = timeStr.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
      
      // Special cases for sorting
      if (cleanTime == 'ALL DAY' || cleanTime == 'TODO') {
        return -1;
      }

      // Handle 12-hour AM/PM
      try {
        final date = DateFormat('h:mm a').parse(cleanTime);
        return date.hour * 60 + date.minute;
      } catch (_) {}
      
      // Handle 24-hour HH:mm
      final parts = cleanTime.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return h * 60 + m;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }
}
