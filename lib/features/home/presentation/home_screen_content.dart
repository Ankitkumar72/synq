import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notes/domain/models/note.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/navigation/fade_page_route.dart';
import 'widgets/current_focus_widget.dart';
import 'widgets/next_up_card.dart';
import 'widgets/stats_card.dart';
import '../../focus/presentation/focus_screen.dart';

import '../../notes/presentation/note_detail_screen.dart';
import '../../notes/data/notes_provider.dart';
import '../../attachments/data/image_storage_service.dart';
import '../../tasks/domain/models/task.dart';
import '../../tasks/data/tasks_provider.dart';
import 'dart:io';
import '../../tasks/presentation/pages/task_detail_screen.dart';
import '../../notes/utils/markdown_bridge.dart';
import 'package:intl/intl.dart';
import '../../timeline/presentation/pages/view_event_page.dart';

/// HomeScreen content without the bottom navigation bar (for use in MainShell)
class HomeScreenContent extends ConsumerWidget {
  const HomeScreenContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch providers
    // final notesAsync = ref.watch(notesProvider);
    // final notes = notesAsync.value ?? [];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF555555),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Current Focus Section (Dynamic)
            // Current Focus Section (Dynamic)
            GestureDetector(
              onTap: () => Navigator.of(
                context,
                rootNavigator: true,
              ).push(FadePageRoute(builder: (_) => const FocusScreen())),
              child: const CurrentFocusWidget(),
            ),
            const SizedBox(height: 16),

            // Grid Row (Next Up + Stats)
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  const Expanded(child: NextUpCard()),

                  const SizedBox(width: 16),
                  const Expanded(child: StatsCard()),
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
    return DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase();
  }

  Widget _buildYourTasksSection(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final notes = notesAsync.value ?? [];
    
    final tasksAsync = ref.watch(tasksProvider);
    final tasks = tasksAsync.value ?? [];
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Separate tasks and notes into categories
    final scheduledTasks = tasks.where((t) {
      if (t.scheduledTime == null) return false;
      final scheduledDate = DateTime(t.scheduledTime!.year, t.scheduledTime!.month, t.scheduledTime!.day);
      return scheduledDate.isAtSameMomentAs(today);
    }).toList();

    final scheduledEvents = notes.where((n) {
      if (n.scheduledTime == null) return false;
      final scheduledDate = DateTime(n.scheduledTime!.year, n.scheduledTime!.month, n.scheduledTime!.day);
      return scheduledDate.isAtSameMomentAs(today);
    }).toList();

    // Combine and sort scheduled items
    final allScheduled = [
      ...scheduledTasks.map((t) => _HomeItem.task(t)),
      ...scheduledEvents.map((e) => _HomeItem.event(e)),
    ]..sort((a, b) => a.time!.compareTo(b.time!));

    final unscheduledTasks = tasks.where((t) => t.scheduledTime == null).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    // Only notes that ARE NOT events (no scheduled time)
    final notesOnly = notes.where((n) => n.scheduledTime == null && !n.isTask).toList();

    final hasWorkForToday = allScheduled.isNotEmpty || unscheduledTasks.isNotEmpty;

    if (!hasWorkForToday && notesOnly.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tasks Header / Empty Placeholder
        if (!hasWorkForToday) ...[
          // Only show large placeholder if no notes either, 
          // otherwise show a more compact hint
          if (notesOnly.isEmpty)
            _buildEmptyTasksPlaceholder(context)
          else 
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'NO TASKS FOR TODAY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary.withAlpha(150),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],

        // Scheduled Items Section (Tasks & Events)
        if (allScheduled.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SCHEDULED',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${allScheduled.where((item) => !item.isCompleted).length} remaining',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...allScheduled.map((item) {
            if (item.isTask) {
              return _buildTaskItem(context, ref, item.task!);
            } else {
              return _buildEventItem(context, ref, item.event!);
            }
          }),
        ],

        // Unscheduled Tasks Section (To-Do)
        if (unscheduledTasks.isNotEmpty) ...[
          if (allScheduled.isNotEmpty) const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TO-DO',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${unscheduledTasks.where((t) => !t.isCompleted).length} remaining',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildReorderableUnscheduledSection(context, ref, unscheduledTasks),
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

  Widget _buildReorderableUnscheduledSection(
    BuildContext context,
    WidgetRef ref,
    List<Task> unscheduledTasks,
  ) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: unscheduledTasks.length,
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          elevation: 4,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(16),
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final reordered = List<Task>.from(unscheduledTasks);
        final item = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, item);
        final orderedIds = reordered.map((t) => t.id).toList();
        ref.read(tasksProvider.notifier).reorderTasks(orderedIds);
      },
      itemBuilder: (context, index) {
        final task = unscheduledTasks[index];
        return ReorderableDragStartListener(
          key: ValueKey(task.id),
          index: index,
          child: _buildTaskItem(context, ref, task),
        );
      },
    );
  }

  Widget _buildEmptyTasksPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.textSecondary.withAlpha(20)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.task_alt,
            size: 32,
            color: AppColors.textSecondary.withAlpha(100),
          ),
          const SizedBox(height: 12),
          Text(
            'No tasks yet',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
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
          Icon(
            Icons.task_alt,
            size: 48,
            color: AppColors.textSecondary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, WidgetRef ref, Task task) {
    final priorityColors = {
      TaskPriority.none: Colors.orange, // Restoring default look
      TaskPriority.low: Colors.green,
      TaskPriority.medium: Colors.orange,
      TaskPriority.high: Colors.red,
    };

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        if (task.recurrenceRule == null && task.parentRecurringId == null) {
          return true; // Normal task
        }

        // recurring task - ask user
        return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return SimpleDialog(
              title: const Text('Delete Repeating Task'),
              children: [
                SimpleDialogOption(
                  onPressed: () {
                    // This only
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Delete this task only'),
                  ),
                ),
                SimpleDialogOption(
                  onPressed: () {
                    // Future
                    ref
                        .read(tasksProvider.notifier)
                        .deleteFutureInstances(task);
                    Navigator.pop(dialogContext, false); // Manual update
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Delete this and future tasks'),
                  ),
                ),
                SimpleDialogOption(
                  onPressed: () {
                    // All
                    ref.read(tasksProvider.notifier).deleteAllInstances(task);
                    Navigator.pop(dialogContext, false); // Manual update
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Delete all tasks in series',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (_) {
        // This is only called if confirmDismiss returns true (Delete This Only or Normal Task)
        ref.read(tasksProvider.notifier).deleteTask(task.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            FadePageRoute(builder: (_) => TaskDetailScreen(task: task)),
          );
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: task.isCompleted
                ? null
                : Border.all(
                    color: priorityColors[task.priority]!.withAlpha(100),
                    width: 1,
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => ref
                        .read(tasksProvider.notifier)
                        .toggleCompleted(task.id),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: task.isCompleted
                            ? AppColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: task.isCompleted
                              ? AppColors.primary
                              : priorityColors[task.priority]!,
                          width: 2,
                        ),
                      ),
                      child: task.isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
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
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task.isCompleted
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (task.recurrenceRule != null ||
                                task.parentRecurringId != null)
                              const Padding(
                                padding: EdgeInsets.only(right: 4.0),
                                child: Icon(
                                  Icons.repeat,
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            Text(
                              '${task.category.name.toUpperCase()}${task.priority != TaskPriority.none ? ' · ${task.priority.name}' : ''}${task.isAllDay ? ' · ALL DAY' : (task.scheduledTime != null ? ' · ${task.scheduledTime!.hour > 12 ? task.scheduledTime!.hour - 12 : (task.scheduledTime!.hour == 0 ? 12 : task.scheduledTime!.hour)}:${task.scheduledTime!.minute.toString().padLeft(2, '0')} ${task.scheduledTime!.hour >= 12 ? 'PM' : 'AM'}' : '')}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteItem(BuildContext context, WidgetRef ref, Note note) {
    final body = note.body ?? '';
    final plainText = MarkdownBridge.deltaFromMarkdown(body).toPlainText();
    final firstBodyLine = plainText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');

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
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          FadePageRoute(builder: (_) => NoteDetailScreen(noteToEdit: note)),
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
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.title,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.black),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (firstBodyLine.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  firstBodyLine,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Show attachments if any
              if (note.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: note.attachments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filename = note.attachments[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: FutureBuilder<File>(
                            future: ImageStorageService.getFile(filename),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Container(
                                  color: Colors.grey[100],
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                );
                              }
                              if (snapshot.hasError || !snapshot.hasData) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, color: Colors.grey, size: 20),
                                );
                              }
                              return Image.file(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, color: Colors.grey, size: 20),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              // Show links if any
              if (note.links.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: note.links.map((link) {
                    String displayText;
                    try {
                      final uri = Uri.parse(link);
                      displayText = uri.host.replaceFirst('www.', '');
                    } catch (_) {
                      displayText = link.length > 15
                          ? '${link.substring(0, 15)}...'
                          : link;
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            displayText,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventItem(BuildContext context, WidgetRef ref, Note event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: event.isCompleted
            ? null
            : Border.all(
                color: const Color(0xFF5372F6).withAlpha(50),
                width: 1,
              ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            FadePageRoute(builder: (_) => ViewEventPage(event: event)),
          );
        },
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF5372F6).withAlpha(150),
                  width: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: event.isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                      decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'EVENT · ${event.scheduledTime!.hour > 12 ? event.scheduledTime!.hour - 12 : (event.scheduledTime!.hour == 0 ? 12 : event.scheduledTime!.hour)}:${event.scheduledTime!.minute.toString().padLeft(2, "0")} ${event.scheduledTime!.hour >= 12 ? "PM" : "AM"}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeItem {
  final Task? task;
  final Note? event;
  final bool isTask;

  _HomeItem.task(this.task) : event = null, isTask = true;
  _HomeItem.event(this.event) : task = null, isTask = false;

  DateTime? get time => isTask ? task?.scheduledTime : event?.scheduledTime;
  bool get isCompleted => isTask ? task!.isCompleted : event!.isCompleted;
}
