import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';

class ScheduleTimelineContent extends ConsumerWidget {
  const ScheduleTimelineContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedEvents = ref.watch(scheduleEventsProvider);
    final sortedDates = groupedEvents.keys.toList()..sort();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (sortedDates.isEmpty) {
      return Center(
        child: Text(
          'No scheduled tasks found.',
          style: GoogleFonts.roboto(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }
    
    return Container(
      color: AppColors.background,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 80.0, left: 16.0, right: 16.0),
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
                                    ref.read(timelineEventsProvider.notifier).toggleEventCompletion(event.id);
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
    );
  }
}
