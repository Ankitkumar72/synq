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
                  _buildDateTimeBento(),
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

  Widget _buildDateTimeBento() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), // Light grayish background
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.access_time, color: Color(0xFF475569), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Schedule',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E3A8A), // Deep blue label
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'All-day',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _isAllDay,
                      onChanged: (val) {
                        setState(() { _isAllDay = val; });
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0xFF3B82F6), // bright blue
                      inactiveTrackColor: const Color(0xFFE2E8F0), // light gray
                      inactiveThumbColor: Colors.white,
                      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1.5),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FROM',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8), // very light grayish blue
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _selectDate(context, true),
                        child: Text(
                          DateFormat('MMM d, yyyy').format(_startDate),
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            color: const Color(0xFF1E3A8A), // dark blue for date
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (!_isAllDay) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _selectTime(context, true),
                          child: Text(
                            _formatTime(_startTime),
                            style: GoogleFonts.roboto(
                              fontSize: 22,
                              color: const Color(0xFF0F172A), // very dark navy
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TO',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _selectDate(context, false),
                        child: Text(
                          DateFormat('MMM d, yyyy').format(_endDate),
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            color: const Color(0xFF1E3A8A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (!_isAllDay) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _selectTime(context, false),
                          child: Text(
                            _formatTime(_endTime),
                            style: GoogleFonts.roboto(
                              fontSize: 22,
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                Icon(Icons.repeat, size: 18, color: const Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Text(
                  'Does not repeat',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(Icons.language, size: 18, color: const Color(0xFF94A3B8)), // Globe icon
                const SizedBox(width: 8),
                Text(
                  'IST',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
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
