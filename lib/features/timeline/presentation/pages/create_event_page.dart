import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../home/presentation/widgets/create_task_sheet.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/note.dart';
import '../../../../core/domain/models/recurrence_rule.dart';
import '../../data/timeline_provider.dart';
// Adjust this path to where your repeat_settings_screen.dart is located
import '../../../home/presentation/widgets/repeat_settings_screen.dart';

class CreateEventPage extends ConsumerStatefulWidget {
  const CreateEventPage({super.key});

  @override
  ConsumerState<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends ConsumerState<CreateEventPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isAllDay = false;
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now().replacing(
    hour: (TimeOfDay.now().hour + 1) % 24,
  );
  int _selectedChipIndex =
      0; // 0: Event, 1: Task, 2: Working location, 3: Out of office

  // Added recurrence rule state
  RecurrenceRule? _recurrenceRule;
  DateTime? _eventReminderTime;

  int? _selectedColor;
  final List<Map<String, dynamic>> _eventColors = [
    {'name': 'Midnight Velvet', 'color': 0xFF9c528b},
    {'name': 'Neon Blush', 'color': 0xFFf42272},
    {'name': 'Arctic Breeze', 'color': 0xFF9fffcb},
    {'name': 'Solar Ember', 'color': 0xFFc44900},
    {'name': 'Electric Zest', 'color': 0xFFffff3f},
    {'name': 'Candy Aura', 'color': 0xFFFFBBE1},
    {'name': 'Sunset Coral', 'color': 0xFFFF8C9E},
    {'name': 'Cosmic Orchid', 'color': 0xFF7E30E1},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.9;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTitleInput(),
                  const SizedBox(height: 20),
                  _buildTypeChips(),
                  const SizedBox(height: 24),
                  _buildSectionLabel('SCHEDULE'),
                  const SizedBox(height: 8),
                  _buildScheduleCard(
                    date: _formatDateToTitle(_startDate),
                    dateSub: _formatDateToSubtitle(_startDate),
                    time: _isAllDay
                        ? 'All Day'
                        : '${_formatTimeFromTimeOfDay(_startTime)} - ${_formatTimeFromTimeOfDay(_endTime)}',
                    onTap: _openTimePlannerSheet,
                  ),
                  const SizedBox(height: 16),
                  _buildDescriptionBento(),
                  const SizedBox(height: 16),
                  _buildColorPicker(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _handleCreateEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5473F7), // Bright blue
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0x405473F7),
                ),
                icon: const Icon(Icons.add_circle, size: 20),
                label: const Text(
                  'Create Event',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreateEvent() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an event title'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _isAllDay ? 0 : _startTime.hour,
      _isAllDay ? 0 : _startTime.minute,
    );

    DateTime endDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _isAllDay ? 23 : _endTime.hour,
      _isAllDay ? 59 : _endTime.minute,
    );
    if (!_isAllDay && !endDateTime.isAfter(startDateTime)) {
      endDateTime = startDateTime.add(const Duration(hours: 1));
    }

    final event = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: description.isEmpty ? null : description,
      category: NoteCategory.work,
      createdAt: DateTime.now(),
      scheduledTime: startDateTime,
      endTime: endDateTime,
      reminderTime: _eventReminderTime,
      recurrenceRule: _recurrenceRule,
      isTask: false,
      isAllDay: _isAllDay,
      color: _selectedColor,
    );

    try {
      await ref.read(notesProvider.notifier).addNote(event);
      ref.read(selectedDateProvider.notifier).state = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save event: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            color: Colors.black54,
          ),
          const Text(
            'New Event',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          IconButton(
            icon: Icon(
              _eventReminderTime == null
                  ? Icons.notifications_none
                  : Icons.notifications_active_outlined,
            ),
            onPressed: _pickReminderTime,
            color: _eventReminderTime == null
                ? Colors.black54
                : const Color(0xFF5473F7),
            tooltip: _formatReminderLabel(),
          ),
        ],
      ),
    );
  }

  String _formatReminderLabel() {
    if (_eventReminderTime == null) return 'Add reminder';
    final now = DateTime.now();
    if (_eventReminderTime!.year == now.year &&
        _eventReminderTime!.day == now.day) {
      return 'Today, ${_formatTimeFromTimeOfDay(TimeOfDay.fromDateTime(_eventReminderTime!))}';
    }
    return '${_eventReminderTime!.month}/${_eventReminderTime!.day}, ${_formatTimeFromTimeOfDay(TimeOfDay.fromDateTime(_eventReminderTime!))}';
  }

  Future<void> _pickReminderTime() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.notifications_off_outlined,
                  color: Colors.black87,
                ),
                title: const Text(
                  'No reminder',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () => Navigator.pop(context, 'none'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.alarm, color: Colors.black87),
                title: const Text(
                  'At event start',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () => Navigator.pop(context, '0m'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.black87),
                title: const Text(
                  '15 minutes before',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () => Navigator.pop(context, '15m'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.black87),
                title: const Text(
                  '1 hour before',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () => Navigator.pop(context, '1h'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.black87),
                title: const Text(
                  '1 day before',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () => Navigator.pop(context, '1d'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selection == null) return;

    if (selection == 'none') {
      setState(() => _eventReminderTime = null);
      return;
    }

    Duration delta = Duration.zero;
    switch (selection) {
      case '15m':
        delta = const Duration(minutes: 15);
      case '1h':
        delta = const Duration(hours: 1);
      case '1d':
        delta = const Duration(days: 1);
      case '0m':
      default:
        delta = Duration.zero;
    }

    final startDate = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    setState(() {
      _eventReminderTime = startDate.subtract(delta);
    });
  }

  Widget _buildTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('EVENT TITLE'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
          ),
          child: TextField(
            controller: _titleController,
            maxLines: null,
            style: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'What\'s happening?',
              hintStyle: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9AA0A6),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              fillColor: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip('Event', 0, Icons.event_note),
          const SizedBox(width: 8),
          _buildChip('Task', 1, Icons.check_circle_outline),
        ],
      ),
    );
  }

  Widget _buildChip(String label, int index, IconData icon) {
    bool isSelected = _selectedChipIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 1) {
          Navigator.pop(context);
          showCreateTaskSheet(context, initialDate: _startDate);
          return;
        }
        setState(() {
          _selectedChipIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE2E8F0) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade100,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF334155)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.roboto(
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildScheduleCard({
    required String date,
    String? dateSub,
    required String time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Date Section
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                color: Color(0xFF5473F7),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DATE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8A9099),
                      letterSpacing: 0.5,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      dateSub != null ? '$date, $dateSub' : date,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Container(
              height: 40,
              width: 1,
              color: Colors.grey[200],
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),

            // Time Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TIME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8A9099),
                      letterSpacing: 0.5,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      time,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.access_time,
                color: Color(0xFF5473F7),
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateToTitle(DateTime? dt) {
    if (dt == null) {
      return 'Set Date';
    }
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day + 1) {
      return 'Tomorrow';
    }
    return '${dt.day}/${dt.month}';
  }

  String? _formatDateToSubtitle(DateTime? dt) {
    if (dt == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatTimeFromTimeOfDay(TimeOfDay time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // --- Recurrence Helper Methods ---
  Future<({bool applied, RecurrenceRule? rule})> _showRecurrenceDialog({
    RecurrenceRule? initialRule,
    required DateTime startsAt,
  }) async {
    final result = await Navigator.of(context).push<RepeatSettingsResult>(
      MaterialPageRoute(
        builder: (_) =>
            RepeatSettingsScreen(initialRule: initialRule, startsAt: startsAt),
      ),
    );

    if (!mounted || result == null) {
      return (applied: false, rule: initialRule);
    }

    return (applied: true, rule: result.rule);
  }

  String _formatRecurrenceLabelForRule(RecurrenceRule? rule) {
    if (rule == null) return 'No Repeat';

    final unit = _recurrenceUnitLabel(rule.unit);
    if (rule.interval <= 1) {
      return 'Every $unit';
    }
    return 'Every ${rule.interval} ${unit}s';
  }

  String _recurrenceUnitLabel(RecurrenceUnit unit) {
    switch (unit) {
      case RecurrenceUnit.day:
        return 'day';
      case RecurrenceUnit.week:
        return 'week';
      case RecurrenceUnit.month:
        return 'month';
      case RecurrenceUnit.year:
        return 'year';
    }
  }

  Future<void> _openTimePlannerSheet() async {
    var selectedDate = _startDate;
    TimeOfDay? selectedStartTime = _startTime;
    TimeOfDay? selectedEndTime = _endTime;
    var selectedIsAllDay = _isAllDay;
    var selectedRule = _recurrenceRule;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final schedulerTheme = Theme.of(context).copyWith(
              brightness: Brightness.dark,
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF5473F7),
                onPrimary: Colors.white,
                surface: Color(0xFF242B35),
                onSurface: Color(0xFFE7EBF0),
              ),
              dividerColor: const Color(0xFF708090),
              textTheme: Theme.of(context).textTheme.copyWith(
                titleLarge: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE7EBF0),
                ),
                bodyLarge: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE7EBF0),
                ),
                bodyMedium: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFBFC7D1),
                ),
              ),
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

            Future<void> setTimeRange() async {
              final pickedStartTime = await showTimePicker(
                context: context,
                initialTime:
                    selectedStartTime ?? const TimeOfDay(hour: 9, minute: 0),
                helpText: 'Select Start Time',
              );
              if (!context.mounted) return;
              if (pickedStartTime == null) return;

              final baseDate = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                pickedStartTime.hour,
                pickedStartTime.minute,
              );
              final suggestedEnd = baseDate.add(const Duration(hours: 1));
              final pickedEndTime = await showTimePicker(
                context: context,
                initialTime:
                    selectedEndTime ?? TimeOfDay.fromDateTime(suggestedEnd),
                helpText: 'Select End Time',
              );
              if (!context.mounted) return;

              setModalState(() {
                selectedStartTime = pickedStartTime;
                selectedEndTime =
                    pickedEndTime ?? TimeOfDay.fromDateTime(suggestedEnd);
                selectedIsAllDay = false;
              });
            }

            Future<void> setRepeatRule() async {
              final startsAt = selectedIsAllDay
                  ? DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                    )
                  : DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedStartTime?.hour ?? 9,
                      selectedStartTime?.minute ?? 0,
                    );

              setState(() {
                _isAllDay = selectedIsAllDay;
                _startDate = selectedDate;
                if (selectedIsAllDay) {
                  _startTime = const TimeOfDay(hour: 0, minute: 0);
                  _endTime = const TimeOfDay(hour: 23, minute: 59);
                } else if (selectedStartTime != null &&
                    selectedEndTime != null) {
                  _startTime = selectedStartTime!;
                  _endTime = selectedEndTime!;
                }
              });

              Navigator.of(context).pop();

              final result = await _showRecurrenceDialog(
                initialRule: selectedRule,
                startsAt: startsAt,
              );
              if (!mounted || !result.applied) return;
              setState(() {
                _recurrenceRule = result.rule;
              });
            }

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
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 3650),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                          onDateChanged: (date) {
                            setModalState(() => selectedDate = date);
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFF708090)),
                        ListTile(
                          visualDensity: const VisualDensity(vertical: -4),
                          leading: const Icon(
                            Icons.access_time,
                            color: Colors.white70,
                          ),
                          title: Text(
                            selectedIsAllDay
                                ? 'All Day'
                                : (selectedStartTime == null ||
                                          selectedEndTime == null
                                      ? 'Set time'
                                      : '${_formatTimeFromTimeOfDay(selectedStartTime!)} - ${_formatTimeFromTimeOfDay(selectedEndTime!)}'),
                            style: const TextStyle(
                              color: Color(0xFFE7EBF0),
                              fontSize: 14,
                            ),
                          ),
                          onTap: setTimeRange,
                        ),
                        const Divider(height: 1, color: Color(0xFF708090)),
                        ListTile(
                          visualDensity: const VisualDensity(vertical: -4),
                          leading: const Icon(
                            Icons.repeat,
                            color: Colors.white70,
                          ),
                          title: Text(
                            _formatRecurrenceLabelForRule(selectedRule),
                            style: const TextStyle(
                              color: Color(0xFFE7EBF0),
                              fontSize: 14,
                            ),
                          ),
                          onTap: setRepeatRule,
                        ),
                        const Divider(height: 1, color: Color(0xFF708090)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _startDate = DateTime.now();
                                    _startTime = TimeOfDay.now();
                                    _endTime = TimeOfDay.now().replacing(
                                      hour: (TimeOfDay.now().hour + 1) % 24,
                                    );
                                    _isAllDay = false;
                                    _recurrenceRule =
                                        null; // Clear rule as well
                                  });
                                  Navigator.pop(context);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(
                                    0xFFEF4444,
                                  ), // red
                                ),
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(
                                        0xFFE7EBF0,
                                      ), // light text
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _isAllDay = selectedIsAllDay;
                                        _startDate = selectedDate;
                                        _recurrenceRule = selectedRule;
                                        if (selectedIsAllDay) {
                                          _startTime = const TimeOfDay(
                                            hour: 0,
                                            minute: 0,
                                          );
                                          _endTime = const TimeOfDay(
                                            hour: 23,
                                            minute: 59,
                                          );
                                        } else {
                                          if (selectedStartTime != null &&
                                              selectedEndTime != null) {
                                            _startTime = selectedStartTime!;
                                            _endTime = selectedEndTime!;
                                          }
                                        }
                                      });
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF5473F7),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Done',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
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
  }

  Widget _buildDescriptionBento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notes, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            _buildSectionLabel('DESCRIPTION'),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 140, // Maximized height
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
          ),
          child: TextField(
            controller: _descriptionController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Add notes, links, or details...',
              hintStyle: GoogleFonts.roboto(
                fontSize: 16,
                color: const Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    String selectedColorName = 'Core Blue';
    Color selectedColorIcon = const Color(0xFF5473F7);

    if (_selectedColor != null) {
      final match = _eventColors.firstWhere(
        (e) => e['color'] == _selectedColor,
        orElse: () => _eventColors.first,
      );
      selectedColorName = match['name'] as String;
      selectedColorIcon = Color(match['color'] as int);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _showColorPickerDialog,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selectedColorIcon,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  selectedColorName,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showColorPickerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: AppColors.surface,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340, maxHeight: 500),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._eventColors.map((colorMap) {
                    final colorInt = colorMap['color'] as int;
                    final colorName = colorMap['name'] as String;
                    final isSelected = _selectedColor == colorInt;

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedColor = colorInt);
                        Navigator.pop(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Color(colorInt)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Color(colorInt),
                                  width: isSelected ? 0 : 3.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Text(
                              colorName,
                              style: TextStyle(
                                fontSize: 16,
                                color: isSelected
                                    ? Colors.black87
                                    : Colors.black54,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      setState(() => _selectedColor = null);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _selectedColor == null
                                  ? const Color(0xFF5473F7)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF5473F7),
                                width: _selectedColor == null ? 0 : 3.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            'Core Blue',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedColor == null
                                  ? Colors.black87
                                  : Colors.black54,
                              fontWeight: _selectedColor == null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
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
      },
    );
  }
}

void showCreateEventSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const CreateEventPage(),
  );
}
