import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/note.dart';

final currentFocusProvider = StreamProvider<Note?>((ref) async* {
  // Emit every 1 second to keep progress bar and timer updated
  await for (final _ in Stream.periodic(const Duration(seconds: 1))) {
    final notes = await ref.watch(notesProvider.future);
    
    
    final activeTask = notes.firstWhereOrNull((n) => n.isActive && !n.isCompleted);
      
    yield activeTask;
  }
});

final currentFocusProgressProvider = Provider<double>((ref) {
  final focusAsync = ref.watch(currentFocusProvider);
  
  return focusAsync.when(
    data: (focus) {
      if (focus == null || focus.scheduledTime == null || focus.endTime == null) {
        return 0.0;
      }
      
      final now = DateTime.now();
      final total = focus.endTime!.difference(focus.scheduledTime!).inSeconds;
      final remaining = focus.endTime!.difference(now).inSeconds;
      
      if (total == 0) return 0.0;
      return (remaining / total).clamp(0.0, 1.0);
    },
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

final currentFocusTimeRemainingProvider = Provider<String>((ref) {
  final focusAsync = ref.watch(currentFocusProvider);
  
  return focusAsync.when(
    data: (focus) {
      if (focus == null || focus.endTime == null) return '';
      
      final remaining = focus.endTime!.difference(DateTime.now());
      
      if (remaining.isNegative) return 'Time\'s Up';
      
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      final seconds = remaining.inSeconds % 60;

      // Format as HH:MM:SS or MM:SS
      if (hours > 0) {
        return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    },
    loading: () => '',
    error: (_, __) => '',
  );
});
