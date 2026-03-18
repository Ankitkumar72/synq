import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/note.dart';

/// Default focus-block duration used when a task has no explicit [endTime].
const _defaultBlockDuration = Duration(hours: 1);

/// Returns all scheduled tasks that conflict with the proposed time range.
///
/// A conflict exists when the proposed block and an existing block overlap.
///
/// * [proposedStart] – the start time of the task being created / edited.
/// * [proposedEnd]   – the end time (nullable; defaults to +1 hour).
/// * [excludeId]     – the id of the task being edited so it doesn't match
///                     against itself.
final scheduleConflictProvider =
    FutureProvider.family<
      List<Note>,
      ({DateTime proposedStart, DateTime? proposedEnd, String? excludeId})
    >((ref, params) async {
      final notes = await ref.watch(notesProvider.future);

      final pStart = params.proposedStart;
      final pEnd = params.proposedEnd ?? pStart.add(_defaultBlockDuration);

      final conflicts = <Note>[];

      for (final note in notes) {
        // Only consider incomplete, scheduled tasks
        if (!note.isTask || note.isCompleted || note.scheduledTime == null) {
          continue;
        }
        // Don't flag the task we're currently editing
        if (params.excludeId != null && note.id == params.excludeId) continue;

        final eStart = note.scheduledTime!;
        final eEnd = note.endTime ?? eStart.add(_defaultBlockDuration);

        // Two blocks conflict only when they overlap.
        // Formally: pStart < eEnd AND eStart < pEnd
        final overlaps = pStart.isBefore(eEnd) && eStart.isBefore(pEnd);

        if (overlaps) conflicts.add(note);
      }

      return conflicts;
    });
