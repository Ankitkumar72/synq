import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../../domain/models/timeline_event.dart';
import '../../../tasks/presentation/widgets/timeline_task_card.dart';
import '../../../tasks/presentation/pages/task_detail_screen.dart';
import '../../../tasks/data/tasks_provider.dart';
import '../../../notes/data/notes_provider.dart';
import '../pages/view_event_page.dart';

class TimelineHourRow extends ConsumerWidget {
  final int hour;
  final List<TimelineEvent> tasksStartingNow;
  final bool isSelectedDateToday;
  final int currentHour;
  final GlobalKey? focusKey;

  const TimelineHourRow({
    super.key,
    required this.hour,
    required this.tasksStartingNow,
    required this.isSelectedDateToday,
    required this.currentHour,
    this.focusKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: focusKey,
      margin: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Column
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _formatHour(hour),
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: (isSelectedDateToday && currentHour == hour)
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: (isSelectedDateToday && currentHour == hour)
                      ? AppColors.primary
                      : AppColors.textSecondary.withAlpha(180),
                ),
              ),
            ),
          ),

          // Main Content Area (The Box)
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  constraints: const BoxConstraints(minHeight: 66),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withAlpha(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: tasksStartingNow.isNotEmpty
                      ? _buildTaskBlocks(context, tasksStartingNow, ref)
                      : const SizedBox.shrink(), // Empty slot is just the white box
                ),
                if (isSelectedDateToday && currentHour == hour)
                  Positioned(
                    left: -4,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment(
                        -1.0,
                        -1.0 + 2.0 * (DateTime.now().minute / 60),
                      ),
                      child: FractionalTranslation(
                        translation: const Offset(0, -0.5),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1.5,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskBlocks(
    BuildContext context,
    List<TimelineEvent> events,
    WidgetRef ref,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: events.map((event) {
        return TimelineTaskCard(
          title: event.title,
          subtitle: event.subtitle,
          timeRange: '${event.startTime} - ${event.endTime}',
          type: TaskType.values.byName(event.type.name),
          tag: event.tag,
          isCompleted: event.isCompleted,
          color: event.color,
          compact: true,
          isActive:
              isSelectedDateToday &&
              _isTaskCurrentlyActive(event.startTime, event.endTime),
          onTap: () {
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
          },
          onToggleCompletion: (_) {
            ref
                .read(timelineEventsProvider.notifier)
                .toggleEventCompletion(event.id);
          },
        );
      }).toList(),
    );
  }

  String _formatHour(int hour) {
    final amPm = hour < 12 ? 'am' : 'pm';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour $amPm';
  }

  bool _isTaskCurrentlyActive(String startTime, String endTime) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _parseMinutes(startTime);
    final endMinutes = _parseMinutes(endTime);

    if (endMinutes < startMinutes) {
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
    return currentMinutes >= startMinutes && currentMinutes < endMinutes;
  }

  int _parseMinutes(String timeStr) {
    try {
      final format = DateFormat("h:mm a");
      final date = format.parse(timeStr.trim().toUpperCase());
      return date.hour * 60 + date.minute;
    } catch (e) {
      return 0;
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
