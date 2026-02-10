import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../../domain/models/timeline_event.dart';
import '../widgets/timeline_task_card.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class TimelineHourBlocks extends ConsumerStatefulWidget {
  const TimelineHourBlocks({super.key});

  @override
  ConsumerState<TimelineHourBlocks> createState() => _TimelineHourBlocksState();
}

class _TimelineHourBlocksState extends ConsumerState<TimelineHourBlocks> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _currentHourKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentHour();
    });
  }
  
  void _scrollToCurrentHour() {
    if (_currentHourKey.currentContext != null) {
      Scrollable.ensureVisible(
        _currentHourKey.currentContext!,
        alignment: 0.3, // Top 30% of screen
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(timelineEventsProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final isSelectedDateToday = selectedDate.year == now.year && 
                             selectedDate.month == now.month && 
                             selectedDate.day == now.day;
    final currentHour = now.hour;
        
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      child: Column(
        children: List.generate(24, (hour) {
          // Find tasks that start in this hour or overlap it
          final hourStartMinutes = hour * 60;
          final hourEndMinutes = (hour + 1) * 60;

          // Check if this hour is covered by a task that started previously
          bool isCoveredByPreviousTask = false;
          for (final event in events) {
            final startMins = _parseToMinutes(event.startTime);
            final endMins = _parseToMinutes(event.endTime);
            if (startMins < hourStartMinutes && endMins > hourStartMinutes) {
              isCoveredByPreviousTask = true;
              break;
            }
          }

          if (isCoveredByPreviousTask) return const SizedBox.shrink();

          // Find task starting in this specific hour
          final taskStartingNow = events.where((e) {
            final startMins = _parseToMinutes(e.startTime);
            return startMins >= hourStartMinutes && startMins < hourEndMinutes;
          }).firstOrNull;

          return IntrinsicHeight(
            key: (isSelectedDateToday && currentHour == hour) ? _currentHourKey : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Time Column
                SizedBox(
                  width: 60,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        taskStartingNow != null 
                            ? taskStartingNow.startTime.toLowerCase() 
                            : _formatHour(hour),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: (isSelectedDateToday && currentHour == hour) 
                              ? FontWeight.bold 
                              : FontWeight.w500,
                          color: (isSelectedDateToday && currentHour == hour)
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (taskStartingNow != null)
                        Text(
                          taskStartingNow.endTime.toLowerCase(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: (isSelectedDateToday && currentHour == hour) 
                                ? FontWeight.bold 
                                : FontWeight.w500,
                            color: (isSelectedDateToday && currentHour == hour)
                                ? AppColors.primary
                                : AppColors.textSecondary,
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
                          clipBehavior: Clip.none,
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
                    child: taskStartingNow != null
                        ? _buildTaskBlock(context, taskStartingNow, ref)
                        : _buildEmptyBlock(),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
  Widget _buildTaskBlock(BuildContext context, TimelineEvent event, WidgetRef ref) {
    final durationMins = _parseToMinutes(event.endTime) - _parseToMinutes(event.startTime);
    final heightFactor = (durationMins / 60.0).clamp(1.0, 5.0);

    return Container(
      constraints: BoxConstraints(minHeight: 70 * heightFactor),
      child: TimelineTaskCard(
        title: event.title,
        subtitle: event.subtitle,
        timeRange: '${event.startTime} - ${event.endTime}',
        type: TaskType.values.byName(event.type.name),
        tag: event.tag,
        isCompleted: event.isCompleted,
        onToggleCompletion: (_) {
          ref.read(timelineEventsProvider.notifier).toggleEventCompletion(event.id);
        },
      ),
    );
  }

  Widget _buildEmptyBlock() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF555555)),
      ),
    );
  }

  String _formatHour(int hour) {
    final amPm = hour < 12 ? 'am' : 'pm';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour $amPm';
  }

  int _parseToMinutes(String timeStr) {
    try {
      final format = DateFormat("h:mm a");
      final date = format.parse(timeStr.trim().toUpperCase());
      return date.hour * 60 + date.minute;
    } catch (e) {
      return 0;
    }
  }
}
