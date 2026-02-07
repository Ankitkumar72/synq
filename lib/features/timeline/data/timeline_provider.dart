import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../agenda/data/meetings_provider.dart';
import '../../notes/data/notes_provider.dart';
import '../domain/models/timeline_event.dart';

final minuteProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (i) => i); // Refresh every 30s for accuracy
});

final timelineEventsProvider = NotifierProvider<TimelineEventsNotifier, List<TimelineEvent>>(() {
  return TimelineEventsNotifier();
});

class TimelineEventsNotifier extends Notifier<List<TimelineEvent>> {
  @override
  List<TimelineEvent> build() {
    // 0. Tick for real-time updates
    ref.watch(minuteProvider);

    // 1. Fetch real data sources
    final meetings = ref.watch(meetingsProvider);
    final notesAsync = ref.watch(notesProvider);
    final notes = notesAsync.value ?? [];
    
    final allEvents = <TimelineEvent>[];

    // 2. Process Meetings
    for (final meeting in meetings) {
      // Parse time range string "10:30 AM - 11:30 AM"
      final parts = meeting.timeRange.split('-');
      String start = parts.isNotEmpty ? parts[0].trim() : "09:00 AM";
      String end = parts.length > 1 ? parts[1].trim() : "10:00 AM";

      allEvents.add(TimelineEvent(
        id: 'meeting_${meeting.hashCode}',
        title: meeting.title,
        subtitle: meeting.items.isNotEmpty ? "${meeting.items.length} agenda items" : "No agenda",
        startTime: start,
        endTime: end,
        type: TimelineEventType.admin,
        tag: 'MEETING',
        isCompleted: false, // Meetings don't have completed state yet
      ));
    }

    // 3. Process Tasks (Notes where isTask = true and has scheduledTime)
    final now = DateTime.now();
    final tasks = notes.where((n) => 
      n.isTask && 
      n.scheduledTime != null && 
      n.scheduledTime!.year == now.year &&
      n.scheduledTime!.month == now.month &&
      n.scheduledTime!.day == now.day
    ).toList();
    for (final task in tasks) {
      // Format time from scheduledTime or default
      final date = task.scheduledTime ?? DateTime.now();
      final startFormat = DateFormat('h:mm a');
      final endFormat = DateFormat('h:mm a');
      
      // Use existing endTime or default duration
      final endTime = task.endTime ?? date.add(const Duration(hours: 1));
      
      allEvents.add(TimelineEvent(
        id: 'task_${task.id}',
        title: task.title,
        subtitle: task.category.name.toUpperCase(),
        startTime: startFormat.format(date),
        endTime: endFormat.format(endTime),
        type: _mapCategoryToType(task.category.name),
        tag: task.category.name.toUpperCase(),
        isCompleted: task.isCompleted, 
      ));
    }

    // 4. Sort and Calculate isCurrent
    allEvents.sort((a, b) => _parseToMinutes(a.startTime).compareTo(_parseToMinutes(b.startTime)));

    // Calculate isCurrent
    // reuse 'now' from above
    final currentMinutes = now.hour * 60 + now.minute;

    // Use a mappable list to update isCurrent
    final processedEvents = allEvents.map((e) {
      final start = _parseToMinutes(e.startTime);
      final end = _parseToMinutes(e.endTime);
      final isNow = currentMinutes >= start && currentMinutes < end;
      // Also check if it's actually today (simplified for daily view assumption)
      // real app would need date check too, but assuming daily view = today
      return e.copyWith(isCurrent: isNow);
    }).toList();

    return processedEvents;
  }

  Future<void> toggleEventCompletion(String eventId) async {
    if (!eventId.startsWith('task_')) return;

    final noteId = eventId.replaceFirst('task_', '');
    if (noteId.isEmpty || noteId == eventId) {
       // Invalid ID format
       return;
    }
    
    await ref.read(notesProvider.notifier).toggleCompleted(noteId);
  }

  TimelineEventType _mapCategoryToType(String category) {
    switch (category.toLowerCase()) {
      case 'work': return TimelineEventType.active;
      case 'personal': return TimelineEventType.rest;
      case 'idea': return TimelineEventType.strategy;
      default: return TimelineEventType.standard;
    }
  }

  int _parseToMinutes(String timeStr) {
    try {
      // Expected format "10:30 AM"
      // Remove spaces and normalize
      timeStr = timeStr.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
      final format = DateFormat("h:mm a");
      final date = format.parse(timeStr);
      return date.hour * 60 + date.minute;
    } catch (e) {
      return 0; // Fallback
    }
  }

  void addTask(TimelineEvent event) {
    // This might be deprecated if we strictly drive from other providers,
    // but useful for manual mock additions.
    state = [...state, event];
  }
}
