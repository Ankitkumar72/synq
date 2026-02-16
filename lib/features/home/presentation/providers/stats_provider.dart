import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../notes/data/notes_provider.dart';

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
  
  return notesAsync.whenData((notes) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayTasks = notes.where((n) {
      if (!n.isTask) return false;
      if (n.scheduledTime == null) return true;

      final scheduledDate = DateTime(
        n.scheduledTime!.year,
        n.scheduledTime!.month,
        n.scheduledTime!.day,
      );
      return scheduledDate.isAtSameMomentAs(today);
    }).toList();

    // Count recurring series once per day on home stats.
    final recurringSeriesCompletion = <String, bool>{};
    var nonRecurringTotal = 0;
    var nonRecurringCompleted = 0;

    for (final task in todayTasks) {
      final isRecurring = task.parentRecurringId != null || task.recurrenceRule != null;
      if (!isRecurring) {
        nonRecurringTotal++;
        if (task.isCompleted) nonRecurringCompleted++;
        continue;
      }

      final seriesId = task.parentRecurringId ?? task.id;
      final alreadyCompleted = recurringSeriesCompletion[seriesId] ?? false;
      recurringSeriesCompletion[seriesId] = alreadyCompleted || task.isCompleted;
    }

    final recurringTotal = recurringSeriesCompletion.length;
    final recurringCompleted = recurringSeriesCompletion.values.where((isDone) => isDone).length;
    final total = nonRecurringTotal + recurringTotal;
    final completed = nonRecurringCompleted + recurringCompleted;
    
    return TaskStats(
      completed: completed,
      total: total,
      percentage: total > 0 ? (completed / total * 100).round() : 0,
    );
  });
});
