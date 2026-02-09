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
    // Filter for ALL TASKS
    final allTasks = notes.where((n) => n.isTask).toList();
    
    final completed = allTasks.where((t) => t.isCompleted).length;
    final total = allTasks.length;
    
    return TaskStats(
      completed: completed,
      total: total,
      percentage: total > 0 ? (completed / total * 100).round() : 0,
    );
  });
});
