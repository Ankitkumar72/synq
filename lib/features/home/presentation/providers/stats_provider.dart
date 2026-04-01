import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../tasks/data/tasks_provider.dart';

class TaskStats {
  final int completed;
  final int total;
  final int percentage;

  TaskStats({
    required this.completed,
    required this.total,
    required this.percentage,
  });
}

final taskStatsProvider = Provider<AsyncValue<TaskStats>>((ref) {
  final notesAsync = ref.watch(notesProvider);
  final tasksAsync = ref.watch(tasksProvider);

  // Combine both AsyncValues
  if (notesAsync.hasError) return AsyncError(notesAsync.error!, notesAsync.stackTrace!);
  if (tasksAsync.hasError) return AsyncError(tasksAsync.error!, tasksAsync.stackTrace!);
  if (notesAsync.isLoading || tasksAsync.isLoading) return const AsyncLoading();

  final notes = notesAsync.value ?? [];
  final tasks = tasksAsync.value ?? [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Filter items that are either:
  // 1. Explicitly scheduled for TODAY
  // 2. Unscheduled (Inbox) - optionally we include these as "Today's" responsibility?
  // Let's stick to what's visible on the Home Screen as "Today's" area.
  // Home Screen shows: "SCHEDULED" (Calendar items for today) + "TO-DO" (All items with NO schedule)

  bool isScheduledForToday(DateTime? scheduledTime) {
    if (scheduledTime == null) return false;
    final date = DateTime(scheduledTime.year, scheduledTime.month, scheduledTime.day);
    return date.isAtSameMomentAs(today);
  }

  bool isUnscheduled(DateTime? scheduledTime) {
    return scheduledTime == null;
  }

  // Today's scope: everything scheduled for today + everything unscheduled
  final todayItems = <dynamic>[];
  
  for (final n in notes) {
    if (n.isTask && (isScheduledForToday(n.scheduledTime) || isUnscheduled(n.scheduledTime))) {
      todayItems.add(n);
    }
  }
  for (final t in tasks) {
    if (isScheduledForToday(t.scheduledTime) || isUnscheduled(t.scheduledTime)) {
      todayItems.add(t);
    }
  }

  // Count logic
  final recurringSeriesCompletion = <String, bool>{};
  var nonRecurringTotal = 0;
  var nonRecurringCompleted = 0;

  for (final item in todayItems) {
    final isRecurring = item.parentRecurringId != null || (item.recurrenceRule != null);
    
    if (!isRecurring) {
      nonRecurringTotal++;
      if (item.isCompleted) nonRecurringCompleted++;
    } else {
      final seriesId = item.parentRecurringId ?? item.id;
      final alreadyDone = recurringSeriesCompletion[seriesId] ?? false;
      recurringSeriesCompletion[seriesId] = alreadyDone || item.isCompleted;
    }
  }

  final total = nonRecurringTotal + recurringSeriesCompletion.length;
  final completed = nonRecurringCompleted + recurringSeriesCompletion.values.where((v) => v).length;

  return AsyncValue.data(TaskStats(
    completed: completed,
    total: total,
    percentage: total > 0 ? (completed / total * 100).round() : 0,
  ));
});
