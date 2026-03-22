import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../notes/data/notes_provider.dart';
import '../../notes/domain/models/note.dart';
import '../domain/models/timeline_event.dart';

final minuteProvider = StreamProvider<int>((ref) {
  return Stream.periodic(
    const Duration(seconds: 30),
    (i) => i,
  ); // Refresh every 30s for accuracy
});

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

enum TimelineViewMode { daily, weekly, monthly, schedule }

/// Provides the current view mode for the timeline section
final timelineViewModeProvider = StateProvider<TimelineViewMode>(
  (ref) => TimelineViewMode.weekly,
);

final datesWithTasksProvider = Provider<Set<DateTime>>((ref) {
  final notesAsync = ref.watch(notesProvider);
  final notes = notesAsync.value ?? [];

  return notes
      .where((n) => n.isTask && n.scheduledTime != null)
      .map(
        (n) => DateTime(
          n.scheduledTime!.year,
          n.scheduledTime!.month,
          n.scheduledTime!.day,
        ),
      )
      .toSet();
});

final timelineEventsProvider =
    NotifierProvider<TimelineEventsNotifier, List<TimelineEvent>>(() {
      return TimelineEventsNotifier();
    });

class TimelineEventsNotifier extends Notifier<List<TimelineEvent>> {
  @override
  List<TimelineEvent> build() {
    // 0. Tick for real-time updates
    ref.watch(minuteProvider);

    // 1. Fetch real data sources (using the SQL optimized provider)
    final selectedDate = ref.watch(selectedDateProvider);
    final notesAsync = ref.watch(timelineTasksProvider(selectedDate));
    final notes = notesAsync.value ?? [];

    final allEvents = <TimelineEvent>[];

    // 2. Process scheduled timeline entries (tasks + events)
    final scheduledEntries = notes
        .where((n) => !n.isAllDay) // Exclude all-day tasks from hourly blocks
        .toList();

    for (final item in scheduledEntries) {
      // Format time from scheduledTime or default
      final date = item.scheduledTime ?? DateTime.now();
      final startFormat = DateFormat('h:mm a');
      final endFormat = DateFormat('h:mm a');

      // Force tasks to 0 duration so the layout engine shrinks them to the minimum height (e.g. 15 mins visually)
      final endTime = item.isTask 
          ? date // Same as start time
          : (item.endTime ?? date.add(const Duration(hours: 1)));
      final prefix = item.isTask ? 'task' : 'event';

      allEvents.add(
        TimelineEvent(
          id: '${prefix}_${item.id}',
          title: item.title,
          subtitle: item.isTask ? item.category.name.toUpperCase() : 'EVENT',
          startTime: startFormat.format(date),
          endTime: endFormat.format(endTime),
          type: _mapCategoryToType(item.category.name),
          kind: item.isTask ? EventKind.task : EventKind.event,
          tag: item.isTask ? item.category.name.toUpperCase() : 'EVENT',
          isCompleted: item.isCompleted,
          color: item.color,
        ),
      );
    }

    // 4. Sort and Calculate isCurrent
    allEvents.sort(
      (a, b) =>
          _parseToMinutes(a.startTime).compareTo(_parseToMinutes(b.startTime)),
    );

    // Calculate isCurrent
    final now = DateTime.now();
    final isSelectedDateToday =
        selectedDate.year == now.year &&
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

  Future<void> rescheduleEvent({
    required String eventId,
    required DateTime date,
    required String newStartTime,
    required String newEndTime,
  }) async {
    final note = _findTimelineNote(eventId);
    if (note == null) return;

    final newStart = _combineDateAndTime(date, newStartTime);
    var newEnd = _combineDateAndTime(date, newEndTime);
    if (!newEnd.isAfter(newStart)) {
      newEnd = newStart.add(const Duration(minutes: 15));
    }

    await ref
        .read(notesProvider.notifier)
        .updateNote(
          note.copyWith(
            scheduledTime: newStart,
            endTime: newEnd,
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> resizeEvent({
    required String eventId,
    required DateTime date,
    required String newEndTime,
  }) async {
    final note = _findTimelineNote(eventId);
    if (note == null) return;

    final baseStart =
        note.scheduledTime ?? DateTime(date.year, date.month, date.day, 0, 0);
    var newEnd = _combineDateAndTime(date, newEndTime);
    if (!newEnd.isAfter(baseStart)) {
      newEnd = baseStart.add(const Duration(minutes: 15));
    }

    await ref
        .read(notesProvider.notifier)
        .updateNote(
          note.copyWith(
            scheduledTime: baseStart,
            endTime: newEnd,
            updatedAt: DateTime.now(),
          ),
        );
  }

  TimelineEventType _mapCategoryToType(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return TimelineEventType.active;
      case 'personal':
        return TimelineEventType.rest;
      case 'idea':
        return TimelineEventType.strategy;
      default:
        return TimelineEventType.standard;
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

  Note? _findTimelineNote(String eventId) {
    final separatorIndex = eventId.indexOf('_');
    if (separatorIndex <= 0 || separatorIndex >= eventId.length - 1) {
      return null;
    }
    final noteId = eventId.substring(separatorIndex + 1);
    final notes = ref.read(notesProvider).value ?? const <Note>[];
    for (final note in notes) {
      if (note.id == noteId) return note;
    }
    return null;
  }

  DateTime _combineDateAndTime(DateTime date, String timeStr) {
    try {
      final parsed = DateFormat('h:mm a').parse(timeStr.trim().toUpperCase());
      return DateTime(
        date.year,
        date.month,
        date.day,
        parsed.hour,
        parsed.minute,
      );
    } catch (_) {
      return DateTime(date.year, date.month, date.day, 0, 0);
    }
  }

  void addTask(TimelineEvent event) {
    state = [...state, event];
  }
}

final scheduleEventsProvider = Provider<Map<DateTime, List<TimelineEvent>>>((
  ref,
) {
  final notesAsync = ref.watch(notesProvider);
  final notes = notesAsync.value ?? [];

  // Include ALL items (tasks and events)
  final items = notes.toList();

  items.sort((a, b) {
    final dateA = a.scheduledTime ?? a.createdAt;
    final dateB = b.scheduledTime ?? b.createdAt;
    return dateA.compareTo(dateB);
  });

  final grouped = <DateTime, List<TimelineEvent>>{};

  for (final item in items) {
    final dateToUse = item.scheduledTime ?? item.createdAt;
    final dateKey = DateTime(dateToUse.year, dateToUse.month, dateToUse.day);

    final startFormat = DateFormat('h:mm a');
    final endFormat = DateFormat('h:mm a');

    String startTimeString = 'TODO';
    if (!item.isTask && item.scheduledTime != null) {
      startTimeString = startFormat.format(item.scheduledTime!);
    } else if (item.isAllDay) {
      startTimeString = 'All Day';
    } else if (item.scheduledTime != null) {
      startTimeString = startFormat.format(item.scheduledTime!);
    }

    String endTimeString = item.endTime != null
        ? endFormat.format(item.endTime!)
        : startTimeString;

    TimelineEventType type = TimelineEventType.standard;
    switch (item.category.name.toLowerCase()) {
      case 'work':
        type = TimelineEventType.active;
        break;
      case 'personal':
        type = TimelineEventType.rest;
        break;
      case 'idea':
        type = TimelineEventType.strategy;
        break;
    }

    String displayTitle = item.title;
    if (item.isTask &&
        item.scheduledTime == null &&
        !displayTitle.toLowerCase().startsWith('todo')) {
      displayTitle = 'TODO - $displayTitle';
    }

    final prefix = item.isTask ? 'task' : 'event';
    final subTag = item.isTask ? item.category.name.toUpperCase() : 'EVENT';

    final event = TimelineEvent(
      id: '${prefix}_${item.id}',
      title: displayTitle,
      subtitle: subTag,
      startTime: startTimeString,
      endTime: endTimeString,
      type: type,
      tag: subTag,
      isCompleted: item.isCompleted,
      color: item.color,
    );

    grouped.putIfAbsent(dateKey, () => []).add(event);
  }

  return grouped;
});
