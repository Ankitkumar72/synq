import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/note.dart';

final currentFocusProvider = Provider<AsyncValue<Note?>>((ref) {
  final notesAsync = ref.watch(notesProvider);
  return notesAsync.whenData((notes) {
    // Only look for an active task (within its scheduled time)
    return notes.firstWhereOrNull(
      (n) => n.isActive && !n.isCompleted,
    );
  });
});

/// Emits the current time every second to drive UI tickers like progress bars
final currentTimeProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final currentFocusProgressProvider = Provider<double>((ref) {
  final focusAsync = ref.watch(currentFocusProvider);
  final now = ref.watch(currentTimeProvider).value ?? DateTime.now();

  return focusAsync.when(
    data: (focus) {
      if (focus == null ||
          focus.scheduledTime == null ||
          focus.endTime == null) {
        return 0.0;
      }

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
  final now = ref.watch(currentTimeProvider).value ?? DateTime.now();

  return focusAsync.when(
    data: (focus) {
      if (focus == null || focus.endTime == null) return '';

      final remaining = focus.endTime!.difference(now);

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
