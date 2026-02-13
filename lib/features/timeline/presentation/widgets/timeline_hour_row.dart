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
    return IntrinsicHeight(
      key: focusKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time Column
          SizedBox(
            width: 85,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tasksStartingNow.isNotEmpty 
                        ? tasksStartingNow.first.startTime.toLowerCase() 
                        : _formatHour(hour),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: (isSelectedDateToday && currentHour == hour) 
                          ? FontWeight.bold 
                          : FontWeight.w500,
                      color: (isSelectedDateToday && currentHour == hour)
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
                if (tasksStartingNow.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tasksStartingNow.last.endTime.toLowerCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: (isSelectedDateToday && currentHour == hour) 
                              ? FontWeight.bold 
                              : FontWeight.w500,
                          color: (isSelectedDateToday && currentHour == hour)
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Timeline Connector Area (Vertical Line)
          Container(
            width: 2,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.grey.shade100,
            child: (isSelectedDateToday && currentHour == hour)
                ? Stack(
                    children: [
                      Positioned(
                        top: 18,
                        left: -4,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  )
                : null,
          ),

          // Task Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: tasksStartingNow.isNotEmpty
                  ? _buildTaskBlocks(context, tasksStartingNow, ref)
                  : _buildEmptyBlock(),
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
            final task = tasks?.where((n) => n.id == event.id).firstOrNull;
            if (task != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskDetailScreen(task: task),
                ),
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

  Widget _buildEmptyBlock() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
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
