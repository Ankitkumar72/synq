import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/note.dart';
import '../../../timeline/presentation/widgets/synq_drawer.dart';

class OverdueTasksPage extends ConsumerStatefulWidget {
  const OverdueTasksPage({super.key});

  @override
  ConsumerState<OverdueTasksPage> createState() => _OverdueTasksPageState();
}

class _OverdueTasksPageState extends ConsumerState<OverdueTasksPage> {
  static const Color bgColor = AppColors.background;
  static const Color accentRed = AppColors.primary;
  static const Color accentOrange = AppColors.primary;
  static const Color textDark = AppColors.textPrimary;
  static const Color textGray = AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    final notes = notesAsync.value ?? [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter and group overdue tasks
    final Map<DateTime, List<Note>> groupedTasks = {};
    int totalOverdue = 0;

    for (final note in notes) {
      if (note.isTask && !note.isCompleted && note.scheduledTime != null) {
        if (note.scheduledTime!.isBefore(now)) {
          final date = DateTime(
            note.scheduledTime!.year,
            note.scheduledTime!.month,
            note.scheduledTime!.day,
          );
          // Group tasks by their scheduled date
          groupedTasks.putIfAbsent(date, () => []).add(note);
          totalOverdue++;
        }
      }
    }

    final sortedDates = groupedTasks.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest overdue dates first

    return Scaffold(
      backgroundColor: bgColor,
      endDrawer: SynqDrawer(),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, totalOverdue),
                if (totalOverdue > 0)
                  _buildSummaryBanner(totalOverdue, groupedTasks.length),
                Expanded(
                  child: totalOverdue == 0
                      ? Center(
                          child: Text(
                            'No overdue tasks!',
                            style: GoogleFonts.inter(
                              color: textGray,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            top: 10,
                            bottom: 40,
                          ),
                          itemCount: sortedDates.length,
                          itemBuilder: (context, index) {
                            final date = sortedDates[index];
                            final tasks = groupedTasks[date]!;
                            return _buildDateGroup(date, tasks, today);
                          },
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
      // The duplicated hardcoded BottomNavigationBar has been removed.
      // The main shell's persistent BottomNavigationBar will inherently handle it.
    );
  }

  Widget _buildHeader(BuildContext context, int totalOverdue) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 20, 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: textDark,
                size: 22,
              ),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          Text(
            'Overdue',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: textDark,
              letterSpacing: -0.5,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.menu, color: textDark, size: 28),
                  onPressed: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(int totalOverdue, int daysCount) {
    final daysText = daysCount == 1 ? '1 day' : '$daysCount days';
    final tasksText =
        totalOverdue == 1 ? '1 overdue task' : '$totalOverdue overdue tasks';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: accentRed.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentRed.withAlpha(40), width: 1),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: accentRed,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You have $tasksText across $daysText',
                style: GoogleFonts.inter(
                  color: accentRed,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateGroup(DateTime date, List<Note> tasks, DateTime today) {
    String dateLabel = DateFormat('MMM d').format(date);
    final difference = today.difference(date).inDays;
    
    if (difference == 0) {
      dateLabel = 'TODAY';
    } else if (difference == 1) {
      dateLabel = 'YESTERDAY';
    } else if (difference > 1 && difference < 7) {
      dateLabel = '$difference DAYS AGO';
    } else {
      dateLabel = dateLabel.toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dateLabel,
                style: GoogleFonts.inter(
                  color: textGray.withAlpha(180),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(
                  color: textGray.withAlpha(50),
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...tasks.map((task) => _buildTaskCard(task)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Note task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(
                color: accentRed,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox empty circle
              GestureDetector(
                onTap: () {
                  ref.read(notesProvider.notifier).toggleCompleted(task.id);
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentRed,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Task details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          task.category.name.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: textGray,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (task.priority != TaskPriority.none) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '•',
                              style: TextStyle(color: textGray, fontSize: 10),
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: accentOrange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.priority.name.toLowerCase(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: textGray,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Reschedule Button
              GestureDetector(
                onTap: () {
                  // TODO: Implement reschedule logic (e.g. open a date picker)
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: textGray.withAlpha(60)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Reschedule',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textDark.withAlpha(200),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
