import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/note.dart';
import '../widgets/weekly_focus_card.dart';
import '../widgets/daily_schedule_card.dart';

class WeeklyTimelineContent extends ConsumerStatefulWidget {
  const WeeklyTimelineContent({super.key});

  @override
  ConsumerState<WeeklyTimelineContent> createState() => _WeeklyTimelineContentState();
}

class _WeeklyTimelineContentState extends ConsumerState<WeeklyTimelineContent> {
  final DateTime _currentWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    final allNotes = notesAsync.value ?? [];

    final weekDays = List.generate(7, (index) => _currentWeekStart.add(Duration(days: index)));

    // Group tasks by date for weekly view
    final tasksByDate = <DateTime, List<Note>>{};
    for (final note in allNotes) {
      if (note.isTask && note.scheduledTime != null) {
        final date = DateTime(
          note.scheduledTime!.year,
          note.scheduledTime!.month,
          note.scheduledTime!.day,
        );
        tasksByDate.putIfAbsent(date, () => []).add(note);
      }
    }

    final startFormat = DateFormat('MMM d');
    final endFormat = DateFormat('MMM d');
    final weekRangeText = '${startFormat.format(_currentWeekStart)} - ${endFormat.format(_currentWeekStart.add(const Duration(days: 6)))}';

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
                      style: GoogleFonts.inter(
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
              GestureDetector(
                onTap: () {
                  ref.read(timelineViewModeProvider.notifier).state = TimelineViewMode.monthly;
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E1), // Light peach color matching design
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calendar_today_outlined, color: Color(0xFFE58D70), size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Weekly Focus Card
          const WeeklyFocusCard(),
          const SizedBox(height: 32),

          // Schedule Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'SCHEDULE',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: () {
                  ref.read(timelineViewModeProvider.notifier).state = TimelineViewMode.monthly;
                },
                child: Text(
                  'View Calendar',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Days List
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: weekDays.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final date = weekDays[index];
                final normalizedDate = DateTime(date.year, date.month, date.day);
                final dayTasks = tasksByDate[normalizedDate] ?? [];

                return DailyScheduleCard(
                  date: date,
                  tasks: dayTasks,
                  onTap: () {
                    ref.read(selectedDateProvider.notifier).state = date;
                    ref.read(timelineViewModeProvider.notifier).state = TimelineViewMode.daily;
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
