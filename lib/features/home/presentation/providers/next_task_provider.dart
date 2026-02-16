import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/note.dart';

final nextTaskProvider = FutureProvider<List<Note>>((ref) async {
  // Re-fetch when notes change
  final notes = await ref.watch(notesProvider.future);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  
  // Find upcoming incomplete tasks for today only
  final upcomingTasks = notes.where((n) {
    // Basic criteria
    if (!n.isTask || n.isCompleted || n.isAllDay) return false;
    if (n.scheduledTime == null) return false;

    final scheduled = n.scheduledTime!;
    final scheduledDate = DateTime(scheduled.year, scheduled.month, scheduled.day);

    // Must be scheduled today and still upcoming
    return scheduledDate.isAtSameMomentAs(today) && scheduled.isAfter(now);
  }).toList()
    ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));
    
  return upcomingTasks.take(5).toList();
});

final taskCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final notes = await ref.watch(notesProvider.future);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  
  final todayTasks = notes.where((n) {
    if (!n.isTask) return false;
    if (n.scheduledTime == null) return true; // Unscheduled tasks count as "today" or "general"?
    
    final taskDate = DateTime(n.scheduledTime!.year, n.scheduledTime!.month, n.scheduledTime!.day);
    return taskDate.isAtSameMomentAs(today);
  }).toList();
  
  return {
    'total': todayTasks.length,
    'completed': todayTasks.where((t) => t.isCompleted).length,
    'remaining': todayTasks.where((t) => !t.isCompleted).length,
  };
});

final nextTaskTimeUntilProvider = Provider<String>((ref) {
  final nextTasksAsync = ref.watch(nextTaskProvider);
  
  return nextTasksAsync.when(
    data: (tasks) {
      if (tasks.isEmpty) return '';
      final nextTask = tasks.first;
      if (nextTask.isAllDay) return 'All Day';
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
});

