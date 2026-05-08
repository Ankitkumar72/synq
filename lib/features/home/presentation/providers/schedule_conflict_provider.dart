import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synq/features/tasks/data/tasks_provider.dart';
import 'package:synq/features/tasks/domain/models/task.dart';

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
      List<Task>,
      ({DateTime proposedStart, DateTime? proposedEnd, String? excludeId})
    >((ref, params) async {
      final tasks = await ref.watch(tasksProvider.future);

      final pStart = params.proposedStart;
      final pEnd = params.proposedEnd ?? pStart.add(_defaultBlockDuration);

      final conflicts = <Task>[];

      for (final t in tasks) {
        // Only consider incomplete, scheduled tasks
        if (t.isCompleted || t.scheduledTime == null) {
          continue;
        }
        // Don't flag the task we're currently editing
        if (params.excludeId != null && t.id == params.excludeId) continue;

        final eStart = t.scheduledTime!;
        final eEnd = t.endTime ?? eStart.add(_defaultBlockDuration);

        // Two blocks conflict only when they overlap.
        // Formally: pStart < eEnd AND eStart < pEnd
        final overlaps = pStart.isBefore(eEnd) && eStart.isBefore(pEnd);

        if (overlaps) conflicts.add(t);
      }

      return conflicts;
    });
