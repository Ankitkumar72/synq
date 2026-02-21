import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../notes/data/notes_provider.dart';
import '../domain/models/timeline_event.dart';

final minuteProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (i) => i); // Refresh every 30s for accuracy
});

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

enum TimelineViewMode { daily, weekly, monthly }

/// Provides the current view mode for the timeline section
final timelineViewModeProvider = StateProvider<TimelineViewMode>((ref) => TimelineViewMode.weekly);

final datesWithTasksProvider = Provider<Set<DateTime>>((ref) {
  final notesAsync = ref.watch(notesProvider);
  final notes = notesAsync.value ?? [];
  
  return notes
      .where((n) => n.isTask && n.scheduledTime != null)
      .map((n) => DateTime(
            n.scheduledTime!.year,
            n.scheduledTime!.month,
            n.scheduledTime!.day,
          ))
      .toSet();
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
    final notesAsync = ref.watch(notesProvider);
    final notes = notesAsync.value ?? [];
    final selectedDate = ref.watch(selectedDateProvider);
    
    final allEvents = <TimelineEvent>[];

    // 2. Process Tasks (Notes where isTask = true and has scheduledTime)
    final tasks = notes.where((n) => 
      n.isTask && 
      !n.isAllDay && // Exclude all-day tasks from hourly blocks
      n.scheduledTime != null && 
      n.scheduledTime!.year == selectedDate.year &&
      n.scheduledTime!.month == selectedDate.month &&
      n.scheduledTime!.day == selectedDate.day
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
    final now = DateTime.now();
    final isSelectedDateToday = selectedDate.year == now.year && 
                               selectedDate.month == now.month && 
                               selectedDate.day == now.day;
    
    final currentMinutes = now.hour * 60 + now.minute;

    return allEvents.map((e) {
      if (!isSelectedDateToday) return e.copyWith(isCurrent: false);
      
      final start = _parseToMinutes(e.startTime);
      final end = _parseToMinutes(e.endTime);
      final isNow = currentMinutes >= start && currentMinutes < end;
      return e.copyWith(isCurrent: isNow);
    }).toList();
  }

  Future<void> toggleEventCompletion(String eventId) async {
    if (!eventId.startsWith('task_')) return;

    final noteId = eventId.replaceFirst('task_', '');
    if (noteId.isEmpty || noteId == eventId) {
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
      timeStr = timeStr.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
      final format = DateFormat("h:mm a");
      final date = format.parse(timeStr);
      return date.hour * 60 + date.minute;
    } catch (e) {
      return 0;
    }
  }

  void addTask(TimelineEvent event) {
    state = [...state, event];
  }
}

