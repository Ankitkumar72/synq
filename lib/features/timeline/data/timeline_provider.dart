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

    // 3. Process Tasks (Notes where isTask = true)
    final tasks = notes.where((n) => n.isTask).toList();
    for (final task in tasks) {
      // Format time from dueDate or default
      final date = task.dueDate ?? DateTime.now();
      final startFormat = DateFormat('h:mm a');
      final endFormat = DateFormat('h:mm a');
      
      // Default duration 1 hour for tasks
      final endTime = date.add(const Duration(hours: 1));
      
      allEvents.add(TimelineEvent(
        id: 'task_${task.id}',
        title: task.title,
        subtitle: task.category.name.toUpperCase(),
        startTime: startFormat.format(date),
        endTime: endFormat.format(endTime),
        type: _mapCategoryToType(task.category.name),
        tag: task.category.name.toUpperCase(),
        isCompleted: false, // Could map to task status if available
      ));
    }

    // 4. Sort and Calculate isCurrent
    allEvents.sort((a, b) => _parseToMinutes(a.startTime).compareTo(_parseToMinutes(b.startTime)));

    // Calculate isCurrent
    final now = DateTime.now();
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

    // 5. Add default items if empty (Optional, but good for demo)
    // if (processedEvents.isEmpty) {
    //   return _getSampleData();
    // }

    return processedEvents;
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

  List<TimelineEvent> _getSampleData() {
    final now = DateTime.now();
    
    // Helper to format time
    String fmt(int h, int m) {
      final dt = DateTime(now.year, now.month, now.day, h, m);
      return DateFormat('h:mm a').format(dt);
    }

    return [
      TimelineEvent(
        id: 'sample_1',
        title: 'Strategy Planning',
        startTime: fmt(9, 0),
        endTime: fmt(10, 30),
        type: TimelineEventType.strategy,
        tag: 'STRATEGY',
        isCompleted: true,
      ),
      TimelineEvent(
        id: 'sample_2',
        title: 'Deep Work Block',
        subtitle: 'Focus: Core Architecture',
        startTime: fmt(11, 0),
        endTime: fmt(13, 0),
        type: TimelineEventType.active,
        isCurrent: true,
        isCompleted: false,
      ),
    ];
  }

  void addTask(TimelineEvent event) {
    // This might be deprecated if we strictly drive from other providers,
    // but useful for manual mock additions.
    state = [...state, event];
  }
}
