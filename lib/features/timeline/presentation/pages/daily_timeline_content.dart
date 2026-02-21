import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../widgets/calendar_selector.dart';
import '../../../home/presentation/widgets/create_task_sheet.dart';
import '../widgets/timeline_hour_row.dart';
import '../pages/weekly_timeline_content.dart';

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

    // Auto-scroll when switching from monthly or weekly to daily view
    ref.listen(timelineViewModeProvider, (previous, next) {
      if (next == TimelineViewMode.daily) { // Switched to daily
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentHour();
        });
      }
    });
    
    final viewMode = ref.watch(timelineViewModeProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: viewMode == TimelineViewMode.monthly 
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
              if (viewMode == TimelineViewMode.monthly)
                const Expanded(child: CalendarSelector())
              else if (viewMode == TimelineViewMode.weekly)
                const Expanded(child: WeeklyTimelineContent())
              else ...[
                const CalendarSelector(),
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

                                // Find tasks starting in this specific hour
                                final tasksStartingNow = events.where((e) {
                                  final startMins = _parseMinutes(e.startTime);
                                  return startMins >= hourStartMinutes && startMins < hourEndMinutes;
                                }).toList();

                                // Logic to determine if this is the block that should be focused for "now"
                                bool isFocusBlock = false;
                                if (isSelectedDateToday) {
                                  if (hour == currentHour) {
                                    isFocusBlock = !isCoveredByPreviousTask;
                                  } else if (tasksStartingNow.isNotEmpty) {
                                    // If a task starts now and spans over the actual current hour
                                    for (final task in tasksStartingNow) {
                                      final endMins = _parseMinutes(task.endTime);
                                      if (currentHour * 60 >= hourStartMinutes && currentHour * 60 < endMins) {
                                        isFocusBlock = true;
                                        break;
                                      }
                                    }
                                  }
                                }

                                return TimelineHourRow(
                                  hour: hour,
                                  tasksStartingNow: tasksStartingNow,
                                  isSelectedDateToday: isSelectedDateToday,
                                  currentHour: currentHour,
                                  focusKey: isFocusBlock ? _currentHourKey : null,
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

