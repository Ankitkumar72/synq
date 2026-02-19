import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/note.dart';

class CalendarSelector extends ConsumerStatefulWidget {
  const CalendarSelector({super.key});

  @override
  ConsumerState<CalendarSelector> createState() => _CalendarSelectorState();
}

class _CalendarSelectorState extends ConsumerState<CalendarSelector> {
  late DateTime _visibleMonth;
  late PageController _monthPageController;
  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(_today.year, _today.month);
    _monthPageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _monthPageController.dispose();
    super.dispose();
  }

  void _toggleView() {
    final isMonthly = ref.read(calendarViewProvider);
    ref.read(calendarViewProvider.notifier).state = !isMonthly;
    
    if (!isMonthly) {
      // When switching TO monthly (was weekly), sync visible month with selected date
      final selectedDate = ref.read(selectedDateProvider);
      setState(() {
        _visibleMonth = DateTime(selectedDate.year, selectedDate.month);
        _monthPageController = PageController(initialPage: 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final datesWithTasks = ref.watch(datesWithTasksProvider);
    final isMonthly = ref.watch(calendarViewProvider);
    final notesAsync = ref.watch(notesProvider);
    final allNotes = notesAsync.value ?? [];

    // Group tasks by date for monthly view
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

    // Sort tasks chronologically
    for (final date in tasksByDate.keys) {
      tasksByDate[date]!.sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));
    }

    return isMonthly
        ? _buildMonthlyView(context, selectedDate, datesWithTasks, tasksByDate)
        : _buildWeeklyView(context, selectedDate, datesWithTasks);
  }

  Widget _buildHeader({
    required String title,
    String? subtitle,
    required VoidCallback onToggle,
    VoidCallback? onDropdownTap,
    required bool isMonthly,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMonthly)
                  Text(
                    'SCHEDULE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onDropdownTap ?? onToggle,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 26,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMonthly)
                        const Padding(
                          padding: EdgeInsets.only(left: 4, top: 4),
                          child: Icon(Icons.keyboard_arrow_down, size: 28, color: AppColors.textPrimary),
                        ),
                    ],
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
              ],
            ),
          ),
          if (!isMonthly)
            IconButton(
              onPressed: onToggle,
              icon: const Icon(Icons.calendar_view_month, color: AppColors.textPrimary),
            )
          else
            IconButton(
              onPressed: onToggle,
              icon: const Icon(Icons.calendar_view_week, color: AppColors.textPrimary),
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklyView(
      BuildContext context, DateTime selectedDate, Set<DateTime> datesWithTasks) {
    final weekDays = _getWeekDays(selectedDate);
    final weekNumber = _getWeekNumber(selectedDate);

    return Column(
      key: const ValueKey('weekly'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: DateFormat('MMMM yyyy').format(selectedDate),
          subtitle: 'Week $weekNumber',
          onToggle: _toggleView,
          isMonthly: false,
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: weekDays.length,
            itemBuilder: (context, index) {
              final date = weekDays[index];
              final isSelected = _isSameDay(date, selectedDate);
              final hasTasks = datesWithTasks.any((d) => _isSameDay(d, date));

              return _buildDayItem(context, date, isSelected, hasTasks);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyView(
      BuildContext context, DateTime selectedDate, Set<DateTime> datesWithTasks, Map<DateTime, List<Note>> tasksByDate) {
    return Column(
      key: const ValueKey('monthly'),
      children: [
        _buildHeader(
          title: DateFormat('MMMM yyyy').format(_visibleMonth),
          onToggle: _toggleView,
          onDropdownTap: () => _showMonthYearPicker(context, selectedDate),
          isMonthly: true,
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (notification is ScrollUpdateNotification) {
                // Update visible month title faster during scroll
                final page = _monthPageController.page ?? 0;
                final index = page.round();
                final newVisibleMonth = DateTime(_today.year, _today.month + index);
                if (newVisibleMonth.month != _visibleMonth.month || newVisibleMonth.year != _visibleMonth.year) {
                  setState(() {
                    _visibleMonth = newVisibleMonth;
                  });
                }
              }
              return false;
            },
            child: PageView.builder(
              controller: _monthPageController,
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              onPageChanged: (index) {
                // final fallback if notification missed it
                setState(() {
                  _visibleMonth = DateTime(_today.year, _today.month + index);
                });
              },
              itemBuilder: (context, index) {
                final monthDate = DateTime(_today.year, _today.month + index);
                return _buildMonthGrid(context, monthDate, selectedDate, datesWithTasks, tasksByDate);
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showMonthYearPicker(BuildContext context, DateTime selectedDate) async {
    DateTime tempDate = _isSameMonth(selectedDate, _visibleMonth) ? selectedDate : _visibleMonth;
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Select Month & Year',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          content: SizedBox(
            width: 300,
            height: 300,
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  onSurface: Colors.black,
                  onPrimary: Colors.white,
                ),
                textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: Colors.black,
                  displayColor: Colors.black,
                ),
              ),
              child: CalendarDatePicker(
                initialDate: tempDate,
                firstDate: DateTime(_today.year - 5),
                lastDate: DateTime(_today.year + 5),
                onDateChanged: (DateTime date) {
                  tempDate = DateTime(date.year, date.month);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(tempDate),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Confirm', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      // Calculate index relative to _today.month
      final monthsDiff = (picked.year - _today.year) * 12 + (picked.month - _today.month);
      
      setState(() {
        _visibleMonth = picked;
      });
      
      _monthPageController.animateToPage(
        monthsDiff,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildMonthGrid(BuildContext context, DateTime monthDate, DateTime selectedDate, Set<DateTime> datesWithTasks, Map<DateTime, List<Note>> tasksByDate) {
    final monthDays = _getMonthDays(monthDate);
    final weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays
                .map((d) => Text(
                      d,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ))
                .toList(),
          ),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.5, // Adjusted from 0.45 for better stability
              ),
              itemCount: 42, // Always show 6 rows
              itemBuilder: (context, index) {
                final date = monthDays[index];
                final isPadding = date.month != monthDate.month;
                final isSelected = _isSameDay(date, selectedDate);
                final dayTasks = tasksByDate[DateTime(date.year, date.month, date.day)] ?? [];

                return _buildGridDayItem(context, date, isSelected, dayTasks, isPadding);
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDayItem(BuildContext context, DateTime date, bool isSelected, bool hasTasks) {
    return GestureDetector(
      onTap: () => ref.read(selectedDateProvider.notifier).state = date,
      child: Container(
        width: 60,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5473F7) : const Color(0xFFF5F7FF),
          borderRadius: BorderRadius.circular(35),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF5473F7).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E').format(date).substring(0, 3),
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white.withValues(alpha: 0.8) : Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              date.day.toString(),
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            if (hasTasks) ...[
              const SizedBox(height: 6),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFF5473F7),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGridDayItem(
      BuildContext context, DateTime date, bool isSelected, List<Note> tasks, bool isPadding) {
    return GestureDetector(
      onTap: () {
        ref.read(selectedDateProvider.notifier).state = date;
        // Redirect to daily timeline by switching back to weekly view
        ref.read(calendarViewProvider.notifier).state = false;
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E1E1E) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              date.day.toString(),
              style: GoogleFonts.inter(
                color: isSelected 
                    ? Colors.white 
                    : (isPadding ? Colors.grey.shade400 : Colors.black87),
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length > 6 ? 7 : tasks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                if (index == 6 && tasks.length > 7) {
                   return Center(
                     child: Text(
                       '···',
                       style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                     ),
                   );
                }
                final task = tasks[index];
                return Opacity(
                  opacity: isPadding ? 0.7 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: (task.category.name.toLowerCase() == 'work' 
                          ? const Color(0xFFE8EEFF) 
                          : const Color(0xFFF0FDF4)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                          size: 8,
                          color: task.isCompleted ? const Color(0xFF5473F7) : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            task.title,
                            style: GoogleFonts.inter(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<DateTime> _getWeekDays(DateTime center) {
    final startOfWeek = center.subtract(Duration(days: center.weekday % 7));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  List<DateTime> _getMonthDays(DateTime source) {
    final firstDayOfMonth = DateTime(source.year, source.month, 1);
    final lastDayOfMonth = DateTime(source.year, source.month + 1, 0);
    
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday % 7;
    
    final days = <DateTime>[];
    
    // Padding previous month
    for (var i = firstWeekday; i > 0; i--) {
      days.add(firstDayOfMonth.subtract(Duration(days: i)));
    }
    
    // Current month
    for (var i = 0; i < daysInMonth; i++) {
      days.add(firstDayOfMonth.add(Duration(days: i)));
    }
    
    // Padding next month to exactly 42 days (6 rows)
    final totalDaysSoFar = days.length;
    final remaining = 42 - totalDaysSoFar;
    for (var i = 1; i <= remaining; i++) {
      days.add(lastDayOfMonth.add(Duration(days: i)));
    }
    
    return days;
  }

  int _getWeekNumber(DateTime date) {
    final dayOfYear = int.parse(DateFormat('D').format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}
