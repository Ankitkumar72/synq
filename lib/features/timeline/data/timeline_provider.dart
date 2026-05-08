import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:synq/features/notes/data/notes_provider.dart';
import 'package:synq/features/notes/domain/models/note.dart';
import 'package:synq/features/timeline/domain/models/timeline_event.dart';

import 'package:synq/features/tasks/data/tasks_provider.dart';
import 'package:synq/core/providers/repository_provider.dart';

final minuteProvider = StreamProvider<int>((ref) {
  return Stream.periodic(
    const Duration(seconds: 30),
    (i) => i,
  ); // Refresh every 30s for accuracy
});

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

enum TimelineViewMode { daily, weekly, monthly, schedule }

/// Provides the current view mode for the timeline section
final timelineViewModeProvider = StateProvider<TimelineViewMode>(
  (ref) => TimelineViewMode.weekly,
);

final datesWithTasksProvider = Provider<Set<DateTime>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final tasks = tasksAsync.value ?? [];

  final notesAsync = ref.watch(notesProvider);
  final notes = notesAsync.value ?? [];

  final taskDates = tasks
      .where((t) => t.scheduledTime != null)
      .map((t) {
        final local = t.scheduledTime!.toLocal();
        return DateTime(local.year, local.month, local.day);
      });

  final noteDates = notes
      .where((n) => !n.isTask && n.scheduledTime != null)
      .map((n) {
        final local = n.scheduledTime!.toLocal();
        return DateTime(local.year, local.month, local.day);
      });

  return {...taskDates, ...noteDates};
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
    final rawSelectedDate = ref.watch(selectedDateProvider);
    // Ensure selectedDate is local for boundary checks
    final selectedDate = rawSelectedDate.toLocal();
    
    final tasksAsync = ref.watch(tasksProvider);
    final tasks = tasksAsync.value ?? [];

    final notesAsync = ref.watch(notesProvider);
    final notes = notesAsync.value ?? [];

    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Process tasks for this day
    final scheduledTasks = tasks.where((t) {
      if (t.isAllDay) return false;
      if (t.scheduledTime == null) return false;
      final local = t.scheduledTime!.toLocal();
      return !local.isBefore(startOfDay) && local.isBefore(endOfDay);
    }).toList();

    // Process notes for this day
    final todaysNotes = notes.where((n) {
      if (n.isTask) return false;
      if (n.isAllDay) return false;
      if (n.scheduledTime == null) return false;
      final local = n.scheduledTime!.toLocal();
      return !local.isBefore(startOfDay) && local.isBefore(endOfDay);
    }).toList();

    final allEvents = <TimelineEvent>[];
    for (final t in scheduledTasks) {
      final date = (t.scheduledTime ?? DateTime.now()).toLocal();
      final startFormat = DateFormat('h:mm a');
      final endFormat = DateFormat('h:mm a');

      final endTime = t.endTime?.toLocal() ?? date.add(const Duration(minutes: 30));

      allEvents.add(
        TimelineEvent(
          id: 'task_${t.id}',
          title: t.title,
          subtitle: t.category.name.toUpperCase(),
          startTime: startFormat.format(date),
          endTime: endFormat.format(endTime),
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
      final date = (n.scheduledTime ?? DateTime.now()).toLocal();
      if (n.isAllDay) continue;
      
      final startFormat = DateFormat('h:mm a');
      final endFormat = DateFormat('h:mm a');

      final duration = n.endTime != null
          ? n.endTime!.toLocal().difference(date).inMinutes
          : 60; // Default 1 hour

      final endTime = date.add(Duration(minutes: duration));

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
    if (eventId.startsWith('task_')) {
      final taskId = eventId.substring(5);
      if (taskId.isEmpty) return;
      await ref.read(tasksProvider.notifier).toggleCompleted(taskId);
    } else if (eventId.startsWith('event_')) {
      final noteId = eventId.substring(6);
      if (noteId.isEmpty) return;
      await ref.read(notesProvider.notifier).toggleCompleted(noteId);
    }
  }

  Future<void> rescheduleEvent({
    required String eventId,
    required DateTime date,
    required String newStartTime,
    required String newEndTime,
  }) async {
    final deviceId = ref.read(deviceIdProvider).value ?? 'unknown';

    final task = ref.read(tasksProvider).value?.where((t) => 'task_${t.id}' == eventId).firstOrNull;
    if (task != null) {
      final newStart = _combineDateAndTime(date, newStartTime).toUtc();
      var newEnd = _combineDateAndTime(date, newEndTime).toUtc();
      if (!newEnd.isAfter(newStart)) {
        newEnd = newStart.add(const Duration(minutes: 15));
      }
      await ref.read(tasksProvider.notifier).updateTask(
        task.copyWith(
          scheduledTime: newStart,
          endTime: newEnd,
          updatedAt: DateTime.now().toUtc(),
          deviceLastEdited: deviceId,
        ),
      );
      return;
    }

    final note = _findTimelineNote(eventId);
    if (note == null) return;

    final newStart = _combineDateAndTime(date, newStartTime).toUtc();
    var newEnd = _combineDateAndTime(date, newEndTime).toUtc();
    if (!newEnd.isAfter(newStart)) {
      newEnd = newStart.add(const Duration(minutes: 15));
    }

    await ref.read(notesProvider.notifier).updateNote(
      note.copyWith(
        scheduledTime: newStart,
        endTime: newEnd,
        updatedAt: DateTime.now().toUtc(),
        deviceLastEdited: deviceId,
      ),
    );
  }

  Future<void> resizeEvent({
    required String eventId,
    required DateTime date,
    required String newEndTime,
  }) async {
    final deviceId = ref.read(deviceIdProvider).value ?? 'unknown';

    final task = ref.read(tasksProvider).value?.where((t) => 'task_${t.id}' == eventId).firstOrNull;
    if (task != null) {
      final baseStart = (task.scheduledTime ?? DateTime(date.year, date.month, date.day, 0, 0)).toUtc();
      var newEnd = _combineDateAndTime(date, newEndTime).toUtc();
      if (!newEnd.isAfter(baseStart)) {
        newEnd = baseStart.add(const Duration(minutes: 15));
      }
      await ref.read(tasksProvider.notifier).updateTask(
        task.copyWith(
          scheduledTime: baseStart,
          endTime: newEnd,
          updatedAt: DateTime.now().toUtc(),
          deviceLastEdited: deviceId,
        ),
      );
      return;
    }

    final note = _findTimelineNote(eventId);
    if (note == null) return;

    final baseStart = (note.scheduledTime ?? DateTime(date.year, date.month, date.day, 0, 0)).toUtc();
    var newEnd = _combineDateAndTime(date, newEndTime).toUtc();
    if (!newEnd.isAfter(baseStart)) {
      newEnd = baseStart.add(const Duration(minutes: 15));
    }

    await ref.read(notesProvider.notifier).updateNote(
      note.copyWith(
        scheduledTime: baseStart,
        endTime: newEnd,
        updatedAt: DateTime.now().toUtc(),
        deviceLastEdited: deviceId,
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
      // Try 12-hour with AM/PM first
      try {
        final date = DateFormat('h:mm a').parse(timeStr);
        return date.hour * 60 + date.minute;
      } catch (_) {}
      // Fall back to 24-hour format (e.g. "14:30")
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return h * 60 + m;
      }
      return 0;
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
    final dateToUse = (n.scheduledTime ?? n.createdAt).toLocal();
    final dateKey = DateTime(dateToUse.year, dateToUse.month, dateToUse.day);

    final startFormat = DateFormat('h:mm a');
    final endFormat = DateFormat('h:mm a');

    String startTimeString = 'TODO';
    if (n.scheduledTime != null) {
      startTimeString = startFormat.format(n.scheduledTime!.toLocal());
    } else if (n.isAllDay) {
      startTimeString = 'All Day';
    }

    String endTimeString = n.endTime != null
        ? endFormat.format(n.endTime!.toLocal())
        : (n.scheduledTime != null
            ? endFormat.format(n.scheduledTime!.toLocal().add(const Duration(hours: 1)))
            : startTimeString);

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
    final dateToUse = (t.scheduledTime ?? t.createdAt).toLocal();
    final dateKey = DateTime(dateToUse.year, dateToUse.month, dateToUse.day);

    final fmt = DateFormat('h:mm a');

    String startTimeString = 'TODO';
    if (t.scheduledTime != null) {
      startTimeString = fmt.format(t.scheduledTime!.toLocal());
    } else if (t.isAllDay) {
      startTimeString = 'All Day';
    }

    // Use real endTime when available, otherwise default +1h
    String endTimeString = startTimeString;
    if (t.endTime != null) {
      endTimeString = fmt.format(t.endTime!.toLocal());
    } else if (t.scheduledTime != null) {
      endTimeString = fmt.format(t.scheduledTime!.toLocal().add(const Duration(hours: 1)));
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
      endTime: endTimeString,
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
    // Try 12-hour AM/PM first
    try {
      final date = DateFormat('h:mm a').parse(timeStr);
      return date.hour * 60 + date.minute;
    } catch (_) {}
    // Fall back to 24-hour
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return h * 60 + m;
    }
    return 0;
  } catch (e) {
    return 0;
  }
}

