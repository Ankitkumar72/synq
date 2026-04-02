import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../notes/data/notes_provider.dart';
import '../../notes/domain/models/note.dart';
import '../domain/models/timeline_event.dart';

import '../../tasks/data/tasks_provider.dart';

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
  final tasksAsync = ref.watch(tasksProvider);
  final tasks = tasksAsync.value ?? [];

  return tasks
      .where((t) => t.scheduledTime != null)
      .map(
        (t) => DateTime(
          t.scheduledTime!.year,
          t.scheduledTime!.month,
          t.scheduledTime!.day,
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

    // 1. Fetch real data sources
    final selectedDate = ref.watch(selectedDateProvider);
    final tasksAsync = ref.watch(timelineTasksProvider(selectedDate));
    final tasks = tasksAsync.value ?? [];

    final notesAsync = ref.watch(notesProvider);
    final notes = notesAsync.value ?? [];

    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final todaysNotes = notes.where((n) {
      if (n.scheduledTime == null) return false;
      return n.scheduledTime!.isAfter(startOfDay) && n.scheduledTime!.isBefore(endOfDay);
    }).toList();

    final allEvents = <TimelineEvent>[];

    // 2. Process tasks
    final scheduledTasks = tasks.where((t) => !t.isAllDay).toList();
    for (final t in scheduledTasks) {
      final date = t.scheduledTime ?? DateTime.now();
      final startFormat = DateFormat('h:mm a');
      final endFormat = DateFormat('h:mm a');

      allEvents.add(
        TimelineEvent(
          id: 'task_${t.id}',
          title: t.title,
          subtitle: t.category.name.toUpperCase(),
          startTime: startFormat.format(date),
          endTime: endFormat.format(date), // tasks shrink to 0 duration
          type: _mapCategoryToType(t.category.name),
          kind: EventKind.task,
          tag: t.category.name.toUpperCase(),
          isCompleted: t.isCompleted,
          color: t.color,
        ),
      );
    }

    // 3. Process notes (events)
    final scheduledNotes = todaysNotes.where((n) => !n.isAllDay).toList();
    for (final n in scheduledNotes) {
      final date = n.scheduledTime ?? DateTime.now();
      final startFormat = DateFormat('h:mm a');
      final endFormat = DateFormat('h:mm a');
      final endTime = n.endTime ?? date.add(const Duration(hours: 1));

      allEvents.add(
        TimelineEvent(
          id: 'event_${n.id}',
          title: n.title,
          subtitle: 'EVENT',
          startTime: startFormat.format(date),
          endTime: endFormat.format(endTime),
          type: _mapCategoryToType(n.category.name),
          kind: EventKind.event,
          tag: 'EVENT',
          isCompleted: n.isCompleted,
          color: n.color,
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
    final task = ref.read(tasksProvider).value?.where((t) => 'task_${t.id}' == eventId).firstOrNull;
    if (task != null) {
      final newStart = _combineDateAndTime(date, newStartTime);
      var newEnd = _combineDateAndTime(date, newEndTime);
      if (!newEnd.isAfter(newStart)) {
        newEnd = newStart.add(const Duration(minutes: 15));
      }
      await ref.read(tasksProvider.notifier).updateTask(
        task.copyWith(scheduledTime: newStart, endTime: newEnd, updatedAt: DateTime.now()),
      );
      return;
    }

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
    final task = ref.read(tasksProvider).value?.where((t) => 'task_${t.id}' == eventId).firstOrNull;
    if (task != null) {
      final baseStart = task.scheduledTime ?? DateTime(date.year, date.month, date.day, 0, 0);
      var newEnd = _combineDateAndTime(date, newEndTime);
      if (!newEnd.isAfter(baseStart)) {
        newEnd = baseStart.add(const Duration(minutes: 15));
      }
      await ref.read(tasksProvider.notifier).updateTask(
        task.copyWith(scheduledTime: baseStart, endTime: newEnd, updatedAt: DateTime.now()),
      );
      return;
    }

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

  final tasksAsync = ref.watch(tasksProvider);
  final tasks = tasksAsync.value ?? [];

  final grouped = <DateTime, List<TimelineEvent>>{};

  // Group notes (events)
  for (final n in notes) {
    if (n.scheduledTime == null && !n.isAllDay) continue;
    final dateToUse = n.scheduledTime ?? n.createdAt;
    final dateKey = DateTime(dateToUse.year, dateToUse.month, dateToUse.day);

    final startFormat = DateFormat('h:mm a');
    final endFormat = DateFormat('h:mm a');

    String startTimeString = 'TODO';
    if (n.scheduledTime != null) {
      startTimeString = startFormat.format(n.scheduledTime!);
    } else if (n.isAllDay) {
      startTimeString = 'All Day';
    }

    String endTimeString = n.endTime != null
        ? endFormat.format(n.endTime!)
        : startTimeString;

    final event = TimelineEvent(
      id: 'event_${n.id}',
      title: n.title,
      subtitle: 'EVENT',
      startTime: startTimeString,
      endTime: endTimeString,
      type: _mapCategoryToTypeForDict(n.category.name),
      tag: 'EVENT',
      isCompleted: n.isCompleted,
      color: n.color,
    );
    grouped.putIfAbsent(dateKey, () => []).add(event);
  }

  // Group tasks
  for (final t in tasks) {
    if (t.scheduledTime == null && !t.isAllDay) continue;
    final dateToUse = t.scheduledTime ?? t.createdAt;
    final dateKey = DateTime(dateToUse.year, dateToUse.month, dateToUse.day);

    final startFormat = DateFormat('h:mm a');

    String startTimeString = 'TODO';
    if (t.scheduledTime != null) {
      startTimeString = startFormat.format(t.scheduledTime!);
    } else if (t.isAllDay) {
      startTimeString = 'All Day';
    }

    String displayTitle = t.title;
    if (t.scheduledTime == null && !displayTitle.toLowerCase().startsWith('todo')) {
      displayTitle = 'TODO - $displayTitle';
    }

    final event = TimelineEvent(
      id: 'task_${t.id}',
      title: displayTitle,
      subtitle: t.category.name.toUpperCase(),
      startTime: startTimeString,
      endTime: startTimeString,
      type: _mapCategoryToTypeForDict(t.category.name),
      tag: t.category.name.toUpperCase(),
      isCompleted: t.isCompleted,
      color: t.color,
    );
    grouped.putIfAbsent(dateKey, () => []).add(event);
  }

  // Sort each day's events
  for (final key in grouped.keys) {
    grouped[key]!.sort((a, b) => _parseToMinutesDict(a.startTime).compareTo(_parseToMinutesDict(b.startTime)));
  }

  return grouped;
});

TimelineEventType _mapCategoryToTypeForDict(String category) {
  switch (category.toLowerCase()) {
    case 'work': return TimelineEventType.active;
    case 'personal': return TimelineEventType.rest;
    case 'idea': return TimelineEventType.strategy;
    default: return TimelineEventType.standard;
  }
}

int _parseToMinutesDict(String timeStr) {
  try {
    if (timeStr == 'TODO' || timeStr == 'All Day') return -1;
    timeStr = timeStr.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
    final format = DateFormat("h:mm a");
    final date = format.parse(timeStr);
    return date.hour * 60 + date.minute;
  } catch (e) {
    return 0;
  }
}

