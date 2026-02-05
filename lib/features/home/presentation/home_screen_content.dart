import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import 'widgets/current_focus_card.dart';
import 'widgets/next_up_card.dart';
import 'widgets/stats_card.dart';
import '../../notes/data/notes_provider.dart';
import '../../timeline/domain/models/timeline_event.dart';
import '../../timeline/data/timeline_provider.dart';
import 'package:intl/intl.dart';
import '../../timeline/presentation/pages/daily_timeline_page.dart';
import '../../notes/domain/models/note.dart';
import '../../profile/presentation/profile_screen.dart';

/// HomeScreen content without the bottom navigation bar (for use in MainShell)
class HomeScreenContent extends ConsumerWidget {
  const HomeScreenContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch providers at the top level
    final timelineEvents = ref.watch(timelineEventsProvider);
    final notes = ref.watch(notesProvider);

    // 2. Calculate Stats
    final completedTasksCount = notes.where((n) => n.isTask && n.isCompleted).length;

    // 3. Calculate Timeline Data (Current & Next)
    // Helper to parse "HH:mm AM/PM" to minutes
    int parseMinutes(String t) {
      try {
        final fmt = DateFormat("h:mm a");
        final d = fmt.parse(t.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase());
        return d.hour * 60 + d.minute;
      } catch (_) {
        return 0;
      }
    }

    final nowDateTime = DateTime.now();
    final currentMinutes = nowDateTime.hour * 60 + nowDateTime.minute;

    // Find current event
    final currentEvent = timelineEvents.where((e) => e.isCurrent).firstOrNull;

    // Find next event:
    // A simple heuristic: the first event that starts AFTER now and isn't completed.
    // Ideally, we'd sort by start time first, but assuming list is sorted or roughly ordered:
    final nextEvent = timelineEvents
        .where((e) {
          final start = parseMinutes(e.startTime);
          return start > currentMinutes && !e.isCompleted;
        })
        .toList()
        .firstOrNull; 
        // Fallback: if no future event, maybe just the next one in the list that isn't this one?
        // keeping it simple for now.

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateHeader(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                    ),
                    Text(
                      'Synq.',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  child: const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Current Focus Section (Dynamic)
            if (currentEvent != null) ...[
                 Builder(
                   builder: (context) {
                      final startMin = parseMinutes(currentEvent.startTime);
                      final endMin = parseMinutes(currentEvent.endTime);
                      
                      final duration = endMin - startMin;
                      final elapsed = currentMinutes - startMin;
                      final progress = duration > 0 ? (elapsed / duration).clamp(0.0, 1.0) : 0.0;
                      final remaining = endMin - currentMinutes;

                      return SizedBox(
                        height: 200,
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => const DailyTimelinePage()),
                          ),
                          child: CurrentFocusCard(
                            title: currentEvent.title,
                            description: currentEvent.subtitle ?? 'Stay focused on your goals.',
                            progress: progress,
                            timeRemaining: remaining > 60 
                                ? '${(remaining / 60).floor()}h ${remaining % 60}m left'
                                : '${remaining}m left',
                            timeRange: '${currentEvent.startTime} - ${currentEvent.endTime}',
                          ),
                        ),
                      );
                   }
                 )
            ] else ...[
               // Fallback / Free Time State
                SizedBox(
                  height: 200,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => const DailyTimelinePage()),
                    ),
                    child: CurrentFocusCard(
                      title: 'Free Time',
                      description: nextEvent != null 
                           ? 'Next up: ${nextEvent.title} at ${nextEvent.startTime}' 
                           : 'No upcoming tasks. Good time to plan or rest.',
                      progress: 0.0,
                      timeRemaining: 'Relax', // Or 'Free'
                      timeRange: 'Now',
                    ),
                  ),
                )
            ],
            const SizedBox(height: 16),

            // Grid Row (Next Up + Stats)
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    child: NextUpCard(
                      title: nextEvent?.title ?? 'All Caught Up',
                      subtitle: nextEvent?.subtitle ?? 'No upcoming events',
                      time: nextEvent?.startTime ?? '--:--',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatsCard(
                      count: completedTasksCount,
                      label: 'Tasks Completed',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // YOUR TASKS Section - dynamic from provider
            _buildYourTasksSection(context, ref),
          ],
        ),
      ),
    );
  }

  String _formatDateHeader() {
    final now = DateTime.now();
    const weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  Widget _buildYourTasksSection(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final tasks = notes.where((n) => n.isTask).toList();
    final notesOnly = notes.where((n) => !n.isTask).toList();

    if (notes.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tasks Section
        if (tasks.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YOUR TASKS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
              ),
              Text(
                '${tasks.where((t) => !t.isCompleted).length} remaining',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tasks.map((task) => _buildTaskItem(context, ref, task)),
        ],

        // Notes Section
        if (notesOnly.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'YOUR NOTES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 12),
          ...notesOnly.map((note) => _buildNoteItem(context, ref, note)),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.task_alt, size: 48, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            'No tasks yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first task',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary.withAlpha(150),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, WidgetRef ref, Note task) {
    final priorityColors = {
      TaskPriority.low: Colors.green,
      TaskPriority.medium: Colors.orange,
      TaskPriority.high: Colors.red,
    };

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => ref.read(notesProvider.notifier).removeNote(task.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: task.isCompleted
              ? null
              : Border.all(color: priorityColors[task.priority]!.withAlpha(100), width: 1),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => ref.read(notesProvider.notifier).toggleCompleted(task.id),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isCompleted ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: task.isCompleted ? AppColors.primary : priorityColors[task.priority]!,
                    width: 2,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          color: task.isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${task.category.name.toUpperCase()} · ${task.priority.name}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteItem(BuildContext context, WidgetRef ref, Note note) {
    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => ref.read(notesProvider.notifier).removeNote(note.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.title,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            if (note.body != null && note.body!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                note.body!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
