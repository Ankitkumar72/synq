import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../../domain/models/timeline_event.dart';
import '../widgets/calendar_selector.dart';
import '../widgets/daily_timeline_view.dart';
import '../widgets/synq_drawer.dart';
import '../../../home/presentation/widgets/create_task_sheet.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/note.dart';
import '../../../notes/presentation/task_detail_screen.dart';
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
      floatingActionButton: GestureDetector(
        onLongPress: () =>
            showCreateTaskSheet(context, initialDate: selectedDate),
        child: FloatingActionButton(
          onPressed: () => showCreateEventSheet(context),
          backgroundColor: AppColors.primary,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatSelectedDate(selectedDate),
                            style: GoogleFonts.roboto(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${events.length} scheduled',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
    final task = _findTaskForEvent(event);
    if (task == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event details not found'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    if (task.isTask) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ViewEventPage(event: task)),
      );
    }
  }

  Note? _findTaskForEvent(TimelineEvent event) {
    final tasks = ref.read(notesProvider).value ?? const <Note>[];
    final separatorIndex = event.id.indexOf('_');
    final noteId = separatorIndex > 0 && separatorIndex < event.id.length - 1
        ? event.id.substring(separatorIndex + 1)
        : event.id;

    for (final task in tasks) {
      if (task.id == noteId) {
        return task;
      }
    }

    for (final task in tasks) {
      if (task.isTask && task.title == event.title) {
        return task;
      }
    }

    return null;
  }

  String _formatSelectedDate(DateTime date) {
    final day = date.day;
    final suffix = (day >= 11 && day <= 13) ? 'th' : _ordinalSuffix(day % 10);
    return '${DateFormat('EEEE, d').format(date)}$suffix';
  }

  String _ordinalSuffix(int digit) {
    switch (digit) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
