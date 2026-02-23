import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../../domain/models/timeline_event.dart';
import 'timeline_task_card.dart';
import '../../../notes/presentation/task_detail_screen.dart';
import '../../../notes/data/notes_provider.dart';

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
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Column
          SizedBox(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _formatHour(hour),
                style: GoogleFonts.inter(
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: const BoxConstraints(minHeight: 80),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withAlpha(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: tasksStartingNow.isNotEmpty
                  ? _buildTaskBlocks(context, tasksStartingNow, ref)
                  : const SizedBox.shrink(), // Empty slot is just the white box
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskBlocks(BuildContext context, List<TimelineEvent> events, WidgetRef ref) {
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
          compact: true,
          isActive: isSelectedDateToday && _isTaskCurrentlyActive(event.startTime, event.endTime),
          onTap: () {
            final tasks = ref.read(notesProvider).value;
            // First try matching exact event ID, fallback to title matching due to some timeline_events being dummy items
            var task = tasks?.where((n) => n.id == event.id).firstOrNull;
            task ??= tasks?.where((n) => n.isTask && n.title == event.title).firstOrNull;
            
            if (task != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskDetailScreen(task: task!),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Task details not found'), duration: Duration(seconds: 1)),
              );
            }
          },
          onToggleCompletion: (_) {
            ref.read(timelineEventsProvider.notifier).toggleEventCompletion(event.id);
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
}
