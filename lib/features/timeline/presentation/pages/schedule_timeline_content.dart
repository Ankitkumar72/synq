import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/presentation/task_detail_screen.dart';

class ScheduleTimelineContent extends ConsumerWidget {
  const ScheduleTimelineContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedEvents = ref.watch(scheduleEventsProvider);
    final sortedDates = groupedEvents.keys.toList()..sort();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Weekly Header Date Calculation
    final currentWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final startFormat = DateFormat('MMM d');
    final endFormat = DateFormat('MMM d');
    final weekRangeText = '${startFormat.format(currentWeekStart)} - ${endFormat.format(currentWeekStart.add(const Duration(days: 6)))}';

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
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 80.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final date = sortedDates[index];
                      final events = groupedEvents[date]!;
                      final isToday = date == today;
                      
                      return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
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
                                DateFormat('E').format(date),
                                style: GoogleFonts.roboto(
                                  color: isToday ? AppColors.primary : Colors.black54,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isToday ? AppColors.primary : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${date.day}',
                                  style: GoogleFonts.roboto(
                                    color: isToday ? Colors.white : Colors.black87,
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 18,
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
                                    final noteId = event.id.replaceFirst('task_', '');
                                    final notes = ref.read(notesProvider).value ?? [];
                                    try {
                                      final note = notes.firstWhere((n) => n.id == noteId);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TaskDetailScreen(task: note),
                                        ),
                                      );
                                    } catch (e) {
                                      // Note not found
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5C84D4), // Matching the blue card color from reference
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              event.isCompleted ? Icons.check_circle : Icons.check_circle_outline,
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
                                                  decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(left: 26.0, top: 4.0),
                                          child: Text(
                                            event.startTime.toLowerCase(), // e.g., 8:30 am
                                            style: GoogleFonts.roboto(
                                              color: Colors.white.withAlpha(210), // white82
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
                },
                childCount: sortedDates.length,
              ),
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
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  fontSize: 26,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down, size: 24, color: AppColors.textSecondary),
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
                      padding: const EdgeInsets.all(10), // Slightly larger padding for the menu button
                      decoration: const BoxDecoration(
                        color: Color(0xFFF6F8FA), // Light grey matching the design in screenshot
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.menu, color: AppColors.textPrimary, size: 24),
                    ),
                  );
                }
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
