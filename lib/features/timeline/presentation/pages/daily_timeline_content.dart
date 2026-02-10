import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../widgets/calendar_selector.dart';
import '../widgets/timeline_task_card.dart';
import '../../../home/presentation/widgets/create_task_sheet.dart';
import '../../domain/models/timeline_event.dart';


/// Timeline page content without bottom navigation bar (for use in MainShell)
class DailyTimelineContent extends ConsumerStatefulWidget {
  const DailyTimelineContent({super.key});

  @override
  ConsumerState<DailyTimelineContent> createState() => _DailyTimelineContentState();
}

class _DailyTimelineContentState extends ConsumerState<DailyTimelineContent> {
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
        alignment: 0.1, // Near the top
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
    
    // Auto-scroll to current hour when switching to today
    ref.listen(selectedDateProvider, (previous, next) {
      final now = DateTime.now();
      if (next.year == now.year && next.month == now.month && next.day == now.day) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentHour();
        });
      }
    });

    // Auto-scroll when switching from monthly to daily view
    ref.listen(calendarViewProvider, (previous, next) {
      if (next == false) { // Switched to daily
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentHour();
        });
      }
    });
    
    final isMonthly = ref.watch(calendarViewProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: isMonthly 
          ? null 
          : FloatingActionButton(
              onPressed: () => showCreateTaskSheet(context, initialDate: selectedDate),
              backgroundColor: AppColors.primary,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            children: [
              isMonthly ? const Expanded(child: CalendarSelector()) : const CalendarSelector(),
              if (!isMonthly)
                Expanded(
                  child: GestureDetector(
                    onTap: _scrollToCurrentHour,
                    behavior: HitTestBehavior.translucent, // Allow taps on empty space to trigger scroll
                    child: CustomScrollView(
                      controller: _scrollController,
                      cacheExtent: 3000, // Ensure current hour block is built even if off-screen
                      physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        sliver: SliverToBoxAdapter(
                          child: GestureDetector(
                            onTap: _scrollToCurrentHour,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatSelectedDate(selectedDate),
                                      style: GoogleFonts.inter(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${events.length} tasks scheduled',
                                      style: GoogleFonts.inter(
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
                        ),
                      ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final hour = index;
                                final now = DateTime.now();
                                final isSelectedDateToday = selectedDate.year == now.year && 
                                                         selectedDate.month == now.month && 
                                                         selectedDate.day == now.day;
                                final currentHour = now.hour;

                                // Find tasks that start in this hour or overlap it
                                // We'll only render a task in the hour it STARTS.
                                // If it spans multiple hours, it will be taller.
                                final hourStartMinutes = hour * 60;
                                final hourEndMinutes = (hour + 1) * 60;

                                // Check if this hour is covered by a task that started previously
                                bool isCoveredByPreviousTask = false;
                                for (final event in events) {
                                  final startMins = _parseMinutes(event.startTime);
                                  final endMins = _parseMinutes(event.endTime);
                                  if (startMins < hourStartMinutes && endMins > hourStartMinutes) {
                                    isCoveredByPreviousTask = true;
                                    break;
                                  }
                                }

                                if (isCoveredByPreviousTask) return const SizedBox.shrink();

                                // Find task starting in this specific hour
                                final taskStartingNow = events.where((e) {
                                  final startMins = _parseMinutes(e.startTime);
                                  return startMins >= hourStartMinutes && startMins < hourEndMinutes;
                                }).firstOrNull;

                                // Logic to determine if this is the block that should be focused for "now"
                                bool isFocusBlock = false;
                                if (isSelectedDateToday) {
                                  if (hour == currentHour) {
                                    isFocusBlock = !isCoveredByPreviousTask;
                                  } else if (taskStartingNow != null) {
                                    // If a task starts now and spans over the actual current hour
                                    final endMins = _parseMinutes(taskStartingNow.endTime);
                                    if (currentHour * 60 >= hourStartMinutes && currentHour * 60 < endMins) {
                                      isFocusBlock = true;
                                    }
                                  }
                                }

                                return IntrinsicHeight(
                                  key: isFocusBlock ? _currentHourKey : null,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Time Column
                                      SizedBox(
                                        width: 60,
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 0.0),
                                            child: Text(
                                              _formatHour(hour),
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
                                          child: taskStartingNow != null
                                              ? _buildTaskBlock(context, taskStartingNow, ref)
                                              : _buildEmptyBlock(),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              childCount: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return DateFormat("EEEE, d'th'").format(date); // Simplified suffix logic for design
    }
    return DateFormat("EEEE, d'th'").format(date);
  }

  Widget _buildTaskBlock(BuildContext context, TimelineEvent event, WidgetRef ref) {
    final durationMins = _parseMinutes(event.endTime) - _parseMinutes(event.startTime);
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

