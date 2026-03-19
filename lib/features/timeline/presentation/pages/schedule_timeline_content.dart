import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/presentation/task_detail_screen.dart';
import '../pages/view_event_page.dart';

class ScheduleTimelineContent extends ConsumerStatefulWidget {
  const ScheduleTimelineContent({super.key});

  @override
  ConsumerState<ScheduleTimelineContent> createState() =>
      _ScheduleTimelineContentState();
}

class _ScheduleTimelineContentState
    extends ConsumerState<ScheduleTimelineContent> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Auto-scroll to today after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final groupedEvents = ref.read(scheduleEventsProvider);
      final sortedDates = groupedEvents.keys.toList()..sort();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int todayIndex = -1;
      for (int i = 0; i < sortedDates.length; i++) {
        if (sortedDates[i].isAtSameMomentAs(today)) {
          todayIndex = i;
          break;
        }
      }

      if (todayIndex != -1) {
        // Find approximate offset to center the item
        final viewportHeight = _scrollController.position.viewportDimension;
        const itemHeight = 120.0; // Approximate height per day block

        final targetOffset =
            (todayIndex * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);

        _scrollController.animateTo(
          targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupedEvents = ref.watch(scheduleEventsProvider);
    final sortedDates = groupedEvents.keys.toList()..sort();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Weekly Header Date Calculation
    final currentWeekStart = DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    );
    final startFormat = DateFormat('MMM d');
    final endFormat = DateFormat('MMM d');
    final weekRangeText =
        '${startFormat.format(currentWeekStart)} - ${endFormat.format(currentWeekStart.add(const Duration(days: 6)))}';

    Widget content;

    if (sortedDates.isEmpty) {
      content = Expanded(
        child: Center(
          child: Text(
            'No scheduled tasks found.',
            style: GoogleFonts.roboto(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ),
      );
    } else {
      content = Expanded(
        child: Container(
          color: AppColors.background,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 80.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final date = sortedDates[index];
                    final events = groupedEvents[date]!;
                    final isToday = date.isAtSameMomentAs(today);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12.0,
                        horizontal: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFFF0F4FF)
                            : Colors.transparent, // Very light blue for today
                        borderRadius: BorderRadius.circular(16),
                        border: isToday
                            ? Border.all(
                                color: AppColors.primary.withAlpha(50),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Column
                          SizedBox(
                            width: 48,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('E').format(date).toUpperCase(),
                                  style: GoogleFonts.roboto(
                                    color: isToday
                                        ? AppColors.primary
                                        : Colors.black54,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${date.day}',
                                    style: GoogleFonts.roboto(
                                      color: isToday
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: isToday
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Tasks Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: events.map((event) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: InkWell(
                                    onTap: () {
                                      final noteId = event.id.replaceFirst(
                                        'task_',
                                        '',
                                      );
                                      final notes =
                                          ref.read(notesProvider).value ?? [];
                                      try {
                                        final note = notes.firstWhere(
                                          (n) => n.id == noteId,
                                        );
                                if (note.isTask) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          TaskDetailScreen(task: note),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ViewEventPage(event: note),
                                    ),
                                  );
                                }
                                      } catch (e) {
                                        // Note not found
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: event.color != null
                                            ? Color(event.color!)
                                            : const Color(0xFF5C84D4),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                event.isCompleted
                                                    ? Icons.check_circle
                                                    : Icons
                                                          .check_circle_outline,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  event.title,
                                                  style: GoogleFonts.roboto(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 15,
                                                    decoration:
                                                        event.isCompleted
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 26.0,
                                              top: 4.0,
                                            ),
                                            child: Text(
                                              event.startTime
                                                  .toLowerCase(), // e.g., 8:30 am
                                              style: GoogleFonts.roboto(
                                                color: Colors.white.withAlpha(
                                                  210,
                                                ), // white82
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }, childCount: sortedDates.length),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT WEEK',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            weekRangeText,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  fontSize: 26,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Builder(
                builder: (context) {
                  return GestureDetector(
                    onTap: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(
                        10,
                      ), // Slightly larger padding for the menu button
                      decoration: const BoxDecoration(
                        color: Color(
                          0xFFF6F8FA,
                        ), // Light grey matching the design in screenshot
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.menu,
                        color: AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          content, // The scroll view or empty state
        ],
      ),
    );
  }
}
