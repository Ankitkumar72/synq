import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/note.dart';

final nextTaskProvider = FutureProvider<Note?>((ref) async {
  // Re-fetch when notes change
  final notes = await ref.watch(notesProvider.future);
  final now = DateTime.now();
  
  // Find next scheduled task that hasn't started yet
  // We filter for tasks that are scheduled AFTER now and are NOT completed.
  // Also ensuring scheduledTime is not null.
  final upcomingTasks = notes
    .where((n) => 
      n.scheduledTime != null && 
      n.scheduledTime!.isAfter(now) &&
      !n.isCompleted
    )
    .toList()
    ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));
    
  return upcomingTasks.firstOrNull;
});

final nextTaskTimeUntilProvider = Provider<String>((ref) {
  final nextTaskAsync = ref.watch(nextTaskProvider);
  
  return nextTaskAsync.when(
    data: (nextTask) {
      if (nextTask?.scheduledTime == null) return '';
      
      final timeUntil = nextTask!.scheduledTime!.difference(DateTime.now());
      final hours = timeUntil.inHours;
      final minutes = timeUntil.inMinutes % 60;
      
      if (hours > 0) return 'in ${hours}h ${minutes}m';
      return 'in ${minutes}m';
    },
    loading: () => '',
    error: (_, __) => '',
  );
});
