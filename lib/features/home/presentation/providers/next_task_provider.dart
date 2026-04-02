import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/note.dart';
import '../../../tasks/data/tasks_provider.dart';


final nextTaskProvider = FutureProvider<List<Note>>((ref) async {
  final notes = await ref.watch(notesProvider.future);
  final tasks = await ref.watch(tasksProvider.future);
  
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // 1. Get Events and Tasks from Notes provider
  final upcomingFromNotes = notes.where((n) {
    // Must be incomplete, timed, and NOT all-day
    // We include both isTask: true and isTask: false (events)
    if (n.isCompleted || n.isAllDay || n.scheduledTime == null) return false;

    final scheduled = n.scheduledTime!;
    final scheduledDate = DateTime(
      scheduled.year,
      scheduled.month,
      scheduled.day,
    );

    // Must be scheduled today and still in the future
    return scheduledDate.isAtSameMomentAs(today) && scheduled.isAfter(now);
  });

  // 2. Get Tasks from dedicated Tasks provider and map to Note for the UI
  final upcomingFromTasks = tasks.where((t) {
    if (t.isCompleted || t.isAllDay || t.scheduledTime == null) return false;
    final scheduled = t.scheduledTime!;
    final scheduledDate = DateTime(scheduled.year, scheduled.month, scheduled.day);
    return scheduledDate.isAtSameMomentAs(today) && scheduled.isAfter(now);
  }).map((t) => Note(
    id: t.id,
    title: t.title,
    scheduledTime: t.scheduledTime,
    category: t.category,
    priority: t.priority,
    isTask: true,
    createdAt: t.createdAt,
  ));

  // 3. Combine and Sort
  final allUpcoming = [...upcomingFromNotes, ...upcomingFromTasks]
    ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));

  return allUpcoming.take(5).toList();
});


final taskCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final notes = await ref.watch(notesProvider.future);
  final tasks = await ref.watch(tasksProvider.future);
  
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Count from Notes that are scheduled for today (Events or migrated tasks)
  final todayNotesTasks = notes.where((n) {
    if (n.scheduledTime == null) return false;
    final taskDate = DateTime(n.scheduledTime!.year, n.scheduledTime!.month, n.scheduledTime!.day);
    return taskDate.isAtSameMomentAs(today);
  }).toList();

  // Count from dedicated Tasks
  final todayTasks = tasks.where((t) {
    if (t.scheduledTime == null) return false;
    final taskDate = DateTime(t.scheduledTime!.year, t.scheduledTime!.month, t.scheduledTime!.day);
    return taskDate.isAtSameMomentAs(today);
  }).toList();

  final notesCompleted = todayNotesTasks.where((t) => t.isCompleted).length;
  final tasksCompleted = todayTasks.where((t) => t.isCompleted).length;

  final totalCount = todayNotesTasks.length + todayTasks.length;
  final totalCompleted = notesCompleted + tasksCompleted;

  return {
    'total': totalCount,
    'completed': totalCompleted,
    'remaining': totalCount - totalCompleted,
  };
});


final nextTaskTimeUntilProvider = StreamProvider<String>((ref) {
  // Emit immediately, then re-emit every minute.
  final controller = StreamController<String>();

  String computeLabel() {
    final tasksAsync = ref.read(nextTaskProvider);
    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) return '';
        final nextTask = tasks.first;
        if (nextTask.scheduledTime == null) return '';

        final now = DateTime.now();
        if (nextTask.scheduledTime!.isBefore(now)) return 'Started';

        final timeUntil = nextTask.scheduledTime!.difference(now);
        final hours = timeUntil.inHours;
        final minutes = timeUntil.inMinutes % 60;

        if (hours > 0) return 'in ${hours}h ${minutes}m';
        return 'in ${minutes}m';
      },
      loading: () => '',
      error: (_, __) => '',
    );
  }

  // Emit the first value right away
  controller.add(computeLabel());

  // Refresh every minute
  final timer = Timer.periodic(const Duration(minutes: 1), (_) {
    if (!controller.isClosed) {
      controller.add(computeLabel());
    }
  });

  // Clean up when the provider is disposed
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});