import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../../domain/models/timeline_event.dart';



class CalendarSelector extends ConsumerStatefulWidget {

  const CalendarSelector({super.key});

  @override
  ConsumerState<CalendarSelector> createState() => _CalendarSelectorState();
}

class _CalendarSelectorState extends ConsumerState<CalendarSelector> {
  static const int _initialPage = 1200; // Offset for infinite scrolling (100 years)
  late PageController _monthPageController;
  late ScrollController _weekScrollController;
  late DateTime _visibleMonth;
  final DateTime _today = DateTime.now();
  bool _hasInitialWeekScroll = false;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(_today.year, _today.month);
    _monthPageController = PageController(initialPage: _initialPage);
    _weekScrollController = ScrollController();
  }

  @override
  void dispose() {
    _monthPageController.dispose();
    _weekScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDate({bool animate = true}) {
    if (!mounted || !_weekScrollController.hasClients) return;

    final selectedDate = ref.read(selectedDateProvider);
    final weekDays = _getWeekDays(selectedDate);
    final index = weekDays.indexWhere((d) => _isSameDay(d, selectedDate));

    if (index >= 0) {
      const itemWidth = 70.0;
      final screenWidth = MediaQuery.of(context).size.width;
      final targetOffset =
          (index * itemWidth) + 16.0 - (screenWidth / 2) + (itemWidth / 2);

      final maxScroll = _weekScrollController.position.maxScrollExtent;
      final offset = targetOffset.clamp(0.0, maxScroll);

      if (animate) {
        _weekScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _weekScrollController.jumpTo(offset);
      }
    }
  }

  void _toggleView() {
    final viewMode = ref.read(timelineViewModeProvider);

    if (viewMode == TimelineViewMode.monthly) {
      ref.read(timelineViewModeProvider.notifier).state =
          TimelineViewMode.weekly;
    } else {
      ref.read(timelineViewModeProvider.notifier).state =
          TimelineViewMode.monthly;

      final selectedDate = ref.read(selectedDateProvider);
      setState(() {
        _visibleMonth = DateTime(selectedDate.year, selectedDate.month);
        // Calculate page index with offset
        final monthsDiff =
            (selectedDate.year - _today.year) * 12 +
            (selectedDate.month - _today.month);
        _monthPageController.jumpToPage(_initialPage + monthsDiff);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final viewMode = ref.watch(timelineViewModeProvider);
    final isMonthly = viewMode == TimelineViewMode.monthly;

    // Listen for date changes to keep week scroll in sync
    ref.listen(selectedDateProvider, (previous, next) {
      if (previous != next && !isMonthly) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToSelectedDate(animate: true);
        });
      }
    });

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.05),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child:
          isMonthly
              ? _buildMonthlyView(context, selectedDate)
              : _buildWeeklyView(context, selectedDate),
    );
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
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onDropdownTap ?? onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
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
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 28,
                            color: AppColors.textPrimary,
                          ),
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
          _buildMenuButton(context),
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: () => Scaffold.of(context).openEndDrawer(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFF6F8FA),
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
    );
  }

  Widget _buildWeeklyView(BuildContext context, DateTime selectedDate) {
    final weekDays = _getWeekDays(selectedDate);
    final weekNumber = _getWeekNumber(selectedDate);
    final datesWithTasks = ref.watch(datesWithTasksProvider);

    if (!_hasInitialWeekScroll) {
      _hasInitialWeekScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedDate(animate: false);
      });
    }

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
            controller: _weekScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: weekDays.length,
            itemBuilder: (context, index) {
              final date = weekDays[index];
              return _DayItem(
                date: date,
                isSelected: _isSameDay(date, selectedDate),
                hasTasks: datesWithTasks.any((d) => _isSameDay(d, date)),
                onTap: () => ref.read(selectedDateProvider.notifier).state = date,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyView(BuildContext context, DateTime selectedDate) {
    final tasksByDate = ref.watch(scheduleEventsProvider);
    final datesWithTasks = ref.watch(datesWithTasksProvider);

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
          child: PageView.builder(
            controller: _monthPageController,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            onPageChanged: (index) {
              setState(() {
                _visibleMonth = DateTime(
                  _today.year,
                  _today.month + (index - _initialPage),
                );
              });
            },
            itemBuilder: (context, index) {
              final monthDate = DateTime(
                _today.year,
                _today.month + (index - _initialPage),
              );
              return _MonthGrid(
                monthDate: monthDate,
                selectedDate: selectedDate,
                datesWithTasks: datesWithTasks,
                tasksByDate: tasksByDate,
                onDateSelected: (date) {
                  ref.read(selectedDateProvider.notifier).state = date;
                  ref.read(timelineViewModeProvider.notifier).state =
                      TimelineViewMode.daily;
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showMonthYearPicker(
    BuildContext context,
    DateTime selectedDate,
  ) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _MonthYearPickerContent(
          initialDate:
              _isSameMonth(selectedDate, _visibleMonth)
                  ? selectedDate
                  : _visibleMonth,
        );
      },
    );

    if (picked != null) {
      final monthsDiff =
          (picked.year - _today.year) * 12 + (picked.month - _today.month);

      setState(() {
        _visibleMonth = picked;
      });

      _monthPageController.animateToPage(
        _initialPage + monthsDiff,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  List<DateTime> _getWeekDays(DateTime center) {
    final startOfWeek = center.subtract(Duration(days: center.weekday - 1));
    return List.generate(14, (index) => startOfWeek.add(Duration(days: index - 3)));
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

class _DayItem extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool hasTasks;
  final VoidCallback onTap;

  const _DayItem({
    required this.date,
    required this.isSelected,
    required this.hasTasks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5473F7) : const Color(0xFFF5F7FF),
          borderRadius: BorderRadius.circular(35),
          border: isToday && !isSelected
              ? Border.all(
                  color: const Color(0xFF5473F7).withValues(alpha: 0.5),
                  width: 1.5,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF5473F7).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E').format(date).substring(0, 3).toUpperCase(),
              style: GoogleFonts.roboto(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.grey.shade500,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              date.day.toString(),
              style: GoogleFonts.roboto(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (hasTasks) ...[
              const SizedBox(height: 6),
              Container(
                width: 4,
                height: 4,
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
}

class _MonthGrid extends StatelessWidget {
  final DateTime monthDate;
  final DateTime selectedDate;
  final Set<DateTime> datesWithTasks;
  final Map<DateTime, List<TimelineEvent>> tasksByDate;
  final Function(DateTime) onDateSelected;

  const _MonthGrid({
    required this.monthDate,
    required this.selectedDate,
    required this.datesWithTasks,
    required this.tasksByDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final monthDays = _getMonthDays(monthDate);
    final weekdays = DateFormat.E().dateSymbols.NARROWWEEKDAYS;

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
          _buildWeekdayHeader(weekdays),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 0.55,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final date = monthDays[index];
                final isPadding = date.month != monthDate.month;
                final isSelected = DateUtils.isSameDay(date, selectedDate);
                final dayEvents = tasksByDate[DateTime(date.year, date.month, date.day)] ?? [];

                return _MonthlyDayCell(
                  date: date,
                  isSelected: isSelected,
                  isPadding: isPadding,
                  events: dayEvents,
                  onTap: () => onDateSelected(date),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader(List<String> weekdays) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekdays.map((d) => Text(
          d,
          style: GoogleFonts.roboto(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        )).toList(),
      ),
    );
  }

  List<DateTime> _getMonthDays(DateTime source) {
    final firstDayOfMonth = DateTime(source.year, source.month, 1);
    final lastDayOfMonth = DateTime(source.year, source.month + 1, 0);

    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = (firstDayOfMonth.weekday - 1);

    final days = <DateTime>[];

    // Previous month padding
    for (var i = firstWeekday; i > 0; i--) {
      days.add(firstDayOfMonth.subtract(Duration(days: i)));
    }

    // Current month
    for (var i = 0; i < daysInMonth; i++) {
      days.add(firstDayOfMonth.add(Duration(days: i)));
    }

    // Next month padding
    final remaining = 42 - days.length;
    for (var i = 1; i <= remaining; i++) {
      days.add(lastDayOfMonth.add(Duration(days: i)));
    }

    return days;
  }
}

class _MonthlyDayCell extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isPadding;
  final List<TimelineEvent> events;
  final VoidCallback onTap;

  const _MonthlyDayCell({
    required this.date,
    required this.isSelected,
    required this.isPadding,
    required this.events,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final visibleEvents = events.take(2).toList();
    final hasMore = events.length > 2;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E1E1E) : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(
                      color: const Color(0xFF5473F7).withValues(alpha: 0.5),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Text(
              date.day.toString(),
              style: GoogleFonts.roboto(
                color: isSelected
                    ? Colors.white
                    : (isPadding ? Colors.grey.shade300 : AppColors.textPrimary),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 4),
          ...visibleEvents.map((e) => _buildEventIndicator(e)),
          if (hasMore) _buildMoreIndicator(events.length - 2),
        ],
      ),
    );
  }

  Widget _buildEventIndicator(TimelineEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2, left: 2, right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: event.color != null 
            ? Color(event.color!).withValues(alpha: 0.15)
            : const Color(0xFFE8EEFF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(
            event.isCompleted ? Icons.check_circle : Icons.circle,
            size: 6,
            color: event.isCompleted 
                ? const Color(0xFF5473F7) 
                : (event.color != null ? Color(event.color!) : Colors.grey.shade400),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              event.title,
              style: GoogleFonts.roboto(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreIndicator(int remaining) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Text(
        '+$remaining more',
        style: GoogleFonts.roboto(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

class _MonthYearPickerContent extends StatefulWidget {

  final DateTime initialDate;

  const _MonthYearPickerContent({required this.initialDate});

  @override
  State<_MonthYearPickerContent> createState() => _MonthYearPickerContentState();
}

class _MonthYearPickerContentState extends State<_MonthYearPickerContent> {
  late DateTime _selectedDate;
  bool _isYearView = false;
  late int _currentYearPage;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentYearPage = (_selectedDate.year ~/ 9) * 9;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shadowColor: Colors.black.withValues(alpha: 0.1),
      elevation: 20,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isYearView ? _buildYearGrid() : _buildMonthGrid(),
            ),
            const SizedBox(height: 24),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Month & Year',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => setState(() => _isYearView = !_isYearView),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(
                    _isYearView
                        ? 'Back to months'
                        : DateFormat('MMMM yyyy').format(_selectedDate),
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isYearView ? Icons.chevron_left : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthGrid() {
    final months = DateFormat.MMM().dateSymbols.STANDALONESHORTMONTHS;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final isSelected = _selectedDate.month == index + 1;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = DateTime(_selectedDate.year, index + 1);
            });
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : const Color(0xFFF5F7FF),
              borderRadius: BorderRadius.circular(12),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                      : [],
            ),
            child: Text(
              months[index],
              style: GoogleFonts.roboto(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildYearGrid() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => setState(() => _currentYearPage -= 9),
            ),
            Text(
              '$_currentYearPage - ${_currentYearPage + 8}',
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () => setState(() => _currentYearPage += 9),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            final year = _currentYearPage + index;
            final isSelected = _selectedDate.year == year;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = DateTime(year, _selectedDate.month);
                  _isYearView = false;
                });
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primary : const Color(0xFFF5F7FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  year.toString(),
                  style: GoogleFonts.roboto(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: AppColors.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _selectedDate),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

