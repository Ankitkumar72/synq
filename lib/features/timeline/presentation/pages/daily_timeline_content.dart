import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/synq_ui_toolkit.dart';
import '../../data/timeline_provider.dart';
import '../../domain/models/timeline_event.dart';
import '../widgets/calendar_selector.dart';
import '../widgets/daily_timeline_view.dart';
import '../widgets/synq_drawer.dart';
import '../../../home/presentation/widgets/create_task_sheet.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../tasks/data/tasks_provider.dart';
import '../../../tasks/presentation/pages/task_detail_screen.dart';
import '../../../shell/presentation/main_shell.dart';
import '../pages/create_event_page.dart';
import '../pages/view_event_page.dart';
import '../pages/schedule_timeline_content.dart';
import '../pages/weekly_timeline_content.dart';

/// Timeline page content without bottom navigation bar (for use in MainShell)
class DailyTimelineContent extends ConsumerStatefulWidget {
  const DailyTimelineContent({super.key});

  @override
  ConsumerState<DailyTimelineContent> createState() =>
      _DailyTimelineContentState();
}

class _DailyTimelineContentState extends ConsumerState<DailyTimelineContent> {
  @override
  Widget build(BuildContext context) {
    final events = ref.watch(timelineEventsProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    ref.listen(currentNavIndexProvider, (previous, next) {
      if (next == 1) {
        final now = DateTime.now();
        final selectedDate = ref.read(selectedDateProvider);
        if (selectedDate.year != now.year ||
            selectedDate.month != now.month ||
            selectedDate.day != now.day) {
          ref.read(selectedDateProvider.notifier).state = now;
        }
      }
    });

    final viewMode = ref.watch(timelineViewModeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      endDrawer: const SynqDrawer(),
      floatingActionButton: SynqFab(
        onLongPress: () =>
            showCreateTaskSheet(context, initialDate: selectedDate),
        onPressed: () => showCreateEventSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            children: [
              if (viewMode == TimelineViewMode.monthly)
                const Expanded(child: CalendarSelector())
              else if (viewMode == TimelineViewMode.weekly)
                const Expanded(child: WeeklyTimelineContent())
              else if (viewMode == TimelineViewMode.schedule)
                const Expanded(child: ScheduleTimelineContent())
              else ...[
                const CalendarSelector(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    child: DailyTimelineView(
                      key: ValueKey(
                        '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}',
                      ),
                      events: events,
                      date: selectedDate,
                      onEventRescheduled: (event, newStart, newEnd) {
                        ref
                            .read(timelineEventsProvider.notifier)
                            .rescheduleEvent(
                              eventId: event.id,
                              date: selectedDate,
                              newStartTime: newStart,
                              newEndTime: newEnd,
                            );
                      },
                      onEventResized: (event, newEnd) {
                        ref
                            .read(timelineEventsProvider.notifier)
                            .resizeEvent(
                              eventId: event.id,
                              date: selectedDate,
                              newEndTime: newEnd,
                            );
                      },
                      onEventTapped: (event) =>
                          _openTaskDetails(context, event),
                      onEmptySlotTap: (tappedTime) =>
                          _showCreateChoiceSheet(context, tappedTime),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateChoiceSheet(BuildContext context, String tappedTime) {
    final selectedDate = ref.read(selectedDateProvider);
    // Parse tapped time into a DateTime for pre-filling.
    DateTime? initialDateTime;
    try {
      final parsed = DateFormat(
        'h:mm a',
      ).parse(tappedTime.trim().toUpperCase());
      initialDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        parsed.hour,
        parsed.minute,
      );
    } catch (_) {
      initialDateTime = selectedDate;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create at $tappedTime',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ChoiceTile(
                    icon: Icons.event_note_rounded,
                    label: 'Event',
                    subtitle: 'With duration',
                    color: const Color(0xFF1A73E8),
                    onTap: () {
                      Navigator.pop(ctx);
                      showCreateEventSheet(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ChoiceTile(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Task',
                    subtitle: 'Due at time',
                    color: const Color(0xFF0F9D58),
                    onTap: () {
                      Navigator.pop(ctx);
                      showCreateTaskSheet(
                        context,
                        initialDate: initialDateTime,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openTaskDetails(BuildContext context, TimelineEvent event) {
    if (event.id.startsWith('task_')) {
      final taskId = event.id.substring(5);
      final tasks = ref.read(tasksProvider).value ?? [];
      try {
        final task = tasks.firstWhere((t) => t.id == taskId);
        Navigator.push(context, MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)));
      } catch (_) {
        _showNotFound(context);
      }
    } else if (event.id.startsWith('event_')) {
      final noteId = event.id.substring(6);
      final notes = ref.read(notesProvider).value ?? [];
      try {
        final note = notes.firstWhere((n) => n.id == noteId);
        Navigator.push(context, MaterialPageRoute(builder: (context) => ViewEventPage(event: note)));
      } catch (_) {
        _showNotFound(context);
      }
    } else {
      _showNotFound(context);
    }
  }

  void _showNotFound(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Event details not found'),
        duration: Duration(seconds: 1),
      ),
    );
  }

}

// ---------------------------------------------------------------------------
// _ChoiceTile — used by the empty-slot bottom sheet
// ---------------------------------------------------------------------------

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: ShapeDecoration(
          color: color.withValues(alpha: 0.08),
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: color.withValues(alpha: 0.2), width: 1.5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
