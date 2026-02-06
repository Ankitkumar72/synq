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

final taskStatsProvider = FutureProvider<TaskStats>((ref) async {
  final notes = await ref.watch(notesProvider.future);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  
  // Filter for today's TASKS
  final todayTasks = notes.where((n) => 
    n.isTask &&
    (n.scheduledTime != null &&
     n.scheduledTime!.isAfter(todayStart) &&
     n.scheduledTime!.isBefore(todayStart.add(const Duration(days: 1))))
  ).toList();
  
  final completed = todayTasks.where((t) => t.isCompleted).length;
  final total = todayTasks.length;
  
  return TaskStats(
    completed: completed,
    total: total,
    percentage: total > 0 ? (completed / total * 100).round() : 0,
  );
});
