import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../home/presentation/widgets/create_task_sheet.dart';

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
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = TimeOfDay.now().replacing(hour: (TimeOfDay.now().hour + 1) % 24);
  int _selectedChipIndex = 0; // 0: Event, 1: Task, 2: Working location, 3: Out of office

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: AppTheme.lightTheme,
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: AppTheme.lightTheme,
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
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
                  _buildOptionsGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'New Event',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Save Event',
              style: GoogleFonts.roboto(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: TextField(
        controller: _titleController,
        style: GoogleFonts.roboto(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'What\'s happening?',
          hintStyle: GoogleFonts.roboto(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          fillColor: Colors.transparent,
        ),
      ),
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
          const SizedBox(width: 8),
          _buildChip('Working location', 2, Icons.work_outline),
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
            Icon(
              icon,
              size: 16,
              color: const Color(0xFF334155),
            ),
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
              child: const Icon(Icons.calendar_today_outlined, color: Color(0xFF5473F7), size: 22),
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
              child: const Icon(Icons.access_time, color: Color(0xFF5473F7), size: 22),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateToTitle(DateTime? dt) {
     if (dt == null) return 'Set Date'; 
     final now = DateTime.now();
     if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return 'Today';
     if (dt.year == now.year && dt.month == now.month && dt.day == now.day + 1) return 'Tomorrow';
     return '${dt.day}/${dt.month}';
  }
   
  String? _formatDateToSubtitle(DateTime? dt) {
     if (dt == null) return null;
     const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
     return '${months[dt.month - 1]} ${dt.day}';
  }
  
  String _formatTimeFromTimeOfDay(TimeOfDay time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _openTimePlannerSheet() async {
    var selectedDate = _startDate;
    TimeOfDay? selectedStartTime = _startTime;
    TimeOfDay? selectedEndTime = _endTime;
    var selectedIsAllDay = _isAllDay;

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
                weekdayStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFBFC7D1),
                  fontWeight: FontWeight.w500,
                ),
                dayStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFE7EBF0),
                ),
                dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF5473F7);
                  }
                  return null;
                }),
                dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return const Color(0xFFE7EBF0);
                }),
                todayForegroundColor: const WidgetStatePropertyAll(Color(0xFFE7EBF0)),
                todayBorder: const BorderSide(color: Color(0xFF5473F7)),
              ),
            );

            Future<void> setTimeRange() async {
              final pickedStartTime = await showTimePicker(
                context: context,
                initialTime: selectedStartTime ?? const TimeOfDay(hour: 9, minute: 0),
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
                initialTime: selectedEndTime ?? TimeOfDay.fromDateTime(suggestedEnd),
                helpText: 'Select End Time',
              );
              if (!context.mounted) return;

              setModalState(() {
                selectedStartTime = pickedStartTime;
                selectedEndTime = pickedEndTime ?? TimeOfDay.fromDateTime(suggestedEnd);
                selectedIsAllDay = false;
              });
            }

            return Theme(
              data: schedulerTheme,
              child: Dialog(
                backgroundColor: const Color(0xFF242B35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                            selectedIsAllDay
                                ? 'All Day'
                                : (selectedStartTime == null || selectedEndTime == null
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
                          leading: const Icon(Icons.repeat, color: Colors.white70),
                          title: const Text(
                            'No Repeat', // Defaulting to No Repeat since events don't have recurrence yet
                            style: TextStyle(
                              color: Color(0xFFE7EBF0),
                              fontSize: 14,
                            ),
                          ),
                          onTap: () {
                            // Events recurrence not fully implemented in UI yet
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Event recurrence coming soon!')),
                            );
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFF708090)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _startDate = DateTime.now();
                                    _endDate = DateTime.now();
                                    _startTime = TimeOfDay.now();
                                    _endTime = TimeOfDay.now().replacing(hour: (TimeOfDay.now().hour + 1) % 24);
                                    _isAllDay = false;
                                  });
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(fontSize: 14, color: Colors.red),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isAllDay = selectedIsAllDay;
                                    _startDate = selectedDate;
                                    _endDate = selectedDate; // Sync end date for events for now
                                    if (selectedIsAllDay) {
                                      _startTime = const TimeOfDay(hour: 0, minute: 0);
                                      _endTime = const TimeOfDay(hour: 23, minute: 59);
                                    } else {
                                      if (selectedStartTime != null && selectedEndTime != null) {
                                        _startTime = selectedStartTime!;
                                        _endTime = selectedEndTime!;
                                      }
                                    }
                                  });
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  'Done',
                                  style: TextStyle(fontSize: 14),
                                ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED), // very light orange
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notes, color: Color(0xFFF97316), size: 18), // orange line icon
              ),
              const SizedBox(width: 12),
              Text(
                'Description & Attachments',
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E3A8A), // dark blue text
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            minLines: 1,
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
        ],
      ),
    );
  }

  Widget _buildOptionsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildSmallOptionCard(
            Icons.person_outline,
            'Guests',
            'Add people',
            const Color(0xFFEFF6FF), // bg light blue
            const Color(0xFF3B82F6), // icon blue
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSmallOptionCard(
            Icons.notifications_none,
            'Alert',
            '30 min before',
            const Color(0xFFFEF2F2), // bg light red
            const Color(0xFFEF4444), // icon red
          ),
        ),
      ],
    );
  }

  Widget _buildSmallOptionCard(IconData icon, String title, String subtitle, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8), // gray-blue for titles
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: const Color(0xFF0F172A), // very dark navy
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final amPm = time.hour < 12 ? 'AM' : 'PM';
    int h = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    String m = time.minute.toString().padLeft(2, '0');
    return '$h:$m $amPm';
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
