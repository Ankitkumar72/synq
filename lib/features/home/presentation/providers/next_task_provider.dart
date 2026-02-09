import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/note.dart';

final nextTaskProvider = FutureProvider<Note?>((ref) async {
  // Re-fetch when notes change
  final notes = await ref.watch(notesProvider.future);
  final now = DateTime.now();
  
  // Find next scheduled task that hasn't started yet
  final upcomingTasks = notes.where((n) {
    if (n.isCompleted) return false;
    if (n.scheduledTime == null) return false;

    // If it's a timed task and it's in the future
    if (!n.isAllDay && n.scheduledTime!.isAfter(now)) return true;

    // If it's an all-day task for today
    if (n.isAllDay) {
      final scheduledDate = DateTime(n.scheduledTime!.year, n.scheduledTime!.month, n.scheduledTime!.day);
      final todayDate = DateTime(now.year, now.month, now.day);
      if (scheduledDate.isAtSameMomentAs(todayDate)) return true;
      if (scheduledDate.isAfter(todayDate)) return true;
    }

    return false;
  }).toList()
    ..sort((a, b) {
      // Prioritize timed tasks over all-day tasks if they are close?
      // For now, just sort by scheduled time. All-day tasks will be "earlier" (midnight)
      // but we might want them to be "fallback" if no timed tasks are coming soon.
      return a.scheduledTime!.compareTo(b.scheduledTime!);
    });
    
  return upcomingTasks.firstOrNull;
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
  final nextTaskAsync = ref.watch(nextTaskProvider);
  
  return nextTaskAsync.when(
    data: (nextTask) {
      if (nextTask == null) return '';
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

