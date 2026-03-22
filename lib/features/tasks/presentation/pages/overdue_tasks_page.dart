import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/navigation/fade_page_route.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/note.dart';
import '../../../notes/presentation/task_detail_screen.dart';
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Image.asset(
              'assets/images/check_logo.png',
              width: 20,
              height: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$tasksText across $daysText',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: textDark,
                  fontWeight: FontWeight.bold,
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
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          FadePageRoute(builder: (_) => TaskDetailScreen(task: task)),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
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

              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await _showCustomRescheduleDialog(context, task, ref);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
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
    ),
  );
}

  Future<void> _showCustomRescheduleDialog(BuildContext context, Note task, WidgetRef ref) async {
    DateTime selectedDate = task.scheduledTime ?? DateTime.now();
    TimeOfDay? selectedTime = task.scheduledTime != null
        ? TimeOfDay.fromDateTime(task.scheduledTime!)
        : null;

    final schedulerTheme = Theme.of(context).copyWith(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF5473F7),
        onPrimary: Colors.white,
        surface: Color(0xFF242B35),
        onSurface: Color(0xFFE7EBF0),
      ),
      dividerColor: const Color(0xFF708090),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: const Color(0xFF242B35),
        headerForegroundColor: const Color(0xFF8A94A6),
        weekdayStyle: const TextStyle(
          fontSize: 13,
          color: Color(0xFFBFC7D1),
          fontWeight: FontWeight.w500,
        ),
        dayStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF475569);
          }
          return const Color(0xFFE7EBF0);
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return const Color(0xFF5473F7);
        }),
        todayBorder: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );

    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Theme(
              data: schedulerTheme,
              child: Dialog(
                backgroundColor: const Color(0xFF242B35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CalendarDatePicker(
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                          onDateChanged: (date) {
                            setModalState(() => selectedDate = date);
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFF708090)),
                        ListTile(
                          visualDensity: const VisualDensity(vertical: -4),
                          leading: const Icon(Icons.access_time, color: Colors.white70),
                          title: Text(
                            selectedTime == null
                                ? 'Set time'
                                : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Color(0xFFE7EBF0), fontSize: 14),
                          ),
                          onTap: () async {
                            final pickedTime = await showTimePicker(
                              context: ctx,
                              initialTime: selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (pickedTime != null) {
                              setModalState(() => selectedTime = pickedTime);
                            }
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFF708090)),
                        ListTile(
                          visualDensity: const VisualDensity(vertical: -4),
                          leading: const Icon(Icons.repeat, color: Colors.white70),
                          title: const Text(
                            'No Repeat',
                            style: TextStyle(color: Color(0xFFE7EBF0), fontSize: 14),
                          ),
                          onTap: () {}, // Optional to implement full repeat here
                        ),
                        const Divider(height: 1, color: Color(0xFF708090)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext, false);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                ),
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext, false),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFE7EBF0),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(dialogContext, true);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF5473F7),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                    ),
                                    child: const Text(
                                      'Done',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (applied == true && context.mounted) {
      final updatedTask = task.copyWith(
        scheduledTime: DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime?.hour ?? 9,
          selectedTime?.minute ?? 0,
        ),
      );
      
      await ref.read(notesProvider.notifier).updateNote(updatedTask);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rescheduled to ${DateFormat('MMM d').format(selectedDate)}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
          ),
        );
      }
    }
  }

}
