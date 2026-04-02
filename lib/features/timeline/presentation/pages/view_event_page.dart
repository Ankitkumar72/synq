import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../notes/domain/models/note.dart';
import '../../../notes/data/notes_provider.dart';

class ViewEventPage extends ConsumerStatefulWidget {
  final Note event;

  const ViewEventPage({super.key, required this.event});

  @override
  ConsumerState<ViewEventPage> createState() => _ViewEventPageState();
}

class _ViewEventPageState extends ConsumerState<ViewEventPage> {
  late TextEditingController _descriptionController;
  Timer? _debounceTimer;

  Note get _currentEvent {
    final notes = ref.read(notesProvider).value;
    return notes?.firstWhere(
          (n) => n.id == widget.event.id,
          orElse: () => widget.event,
        ) ??
        widget.event;
  }

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.event.body);
    _descriptionController.addListener(_onDescriptionChanged);
  }

  void _onDescriptionChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final newBody = _descriptionController.text.trim();
      final currentEvent = _currentEvent;
      if (newBody != (currentEvent.body ?? '')) {
        final updatedEvent = currentEvent.copyWith(body: newBody);
        ref.read(notesProvider.notifier).updateNote(updatedEvent);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _descriptionController.dispose();
    super.dispose();
  }

  void _editTitle() {
    final currentEvent = _currentEvent;
    final controller = TextEditingController(text: currentEvent.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.black87),
          decoration: const InputDecoration(
            hintText: 'Enter event title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                final updatedEvent = currentEvent.copyWith(title: newTitle);
                ref.read(notesProvider.notifier).updateNote(updatedEvent);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatTimeFromTimeOfDay(TimeOfDay time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final p = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $p';
  }

  Future<void> _openTimePlannerSheet() async {
    final currentEvent = _currentEvent;
    var selectedDate = currentEvent.scheduledTime ?? DateTime.now();
    TimeOfDay? selectedStartTime = TimeOfDay.fromDateTime(selectedDate);
    TimeOfDay? selectedEndTime = currentEvent.endTime != null ? TimeOfDay.fromDateTime(currentEvent.endTime!) : selectedStartTime.replacing(hour: (selectedStartTime.hour + 1) % 24);
    var selectedIsAllDay = currentEvent.isAllDay;

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
                titleLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE7EBF0)),
                bodyLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFE7EBF0)),
                bodyMedium: const TextStyle(fontSize: 13, color: Color(0xFFBFC7D1)),
              ),
              datePickerTheme: DatePickerThemeData(
                backgroundColor: const Color(0xFF242B35),
                headerForegroundColor: const Color(0xFF8A94A6),
                weekdayStyle: const TextStyle(fontSize: 13, color: Color(0xFFBFC7D1), fontWeight: FontWeight.w500),
                dayStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return Colors.white;
                  if (states.contains(WidgetState.disabled)) return const Color(0xFF475569);
                  return const Color(0xFFE7EBF0);
                }),
                todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return Colors.white;
                  return const Color(0xFF5473F7);
                }),
                todayBorder: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            );

            Future<void> setTimeRange() async {
              final pickedStartTime = await showTimePicker(
                context: context,
                initialTime: selectedStartTime ?? const TimeOfDay(hour: 9, minute: 0),
                helpText: 'Select Start Time',
              );
              if (!context.mounted || pickedStartTime == null) return;

              final baseDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, pickedStartTime.hour, pickedStartTime.minute);
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                          leading: const Icon( Icons.access_time, color: Colors.white70),
                          title: Text(
                            selectedIsAllDay ? 'All Day' : ('${_formatTimeFromTimeOfDay(selectedStartTime!)} - ${_formatTimeFromTimeOfDay(selectedEndTime!)}'),
                            style: const TextStyle(color: Color(0xFFE7EBF0), fontSize: 14),
                          ),
                          onTap: setTimeRange,
                        ),
                        const Divider(height: 1, color: Color(0xFF708090)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                                child: const Text('Clear', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFE7EBF0)),
                                    child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      final finalStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedStartTime!.hour, selectedStartTime!.minute);
                                      final finalEnd = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedEndTime!.hour, selectedEndTime!.minute);
                                      
                                      final updatedEvent = currentEvent.copyWith(
                                        scheduledTime: finalStart,
                                        endTime: finalEnd,
                                        isAllDay: selectedIsAllDay,
                                      );
                                      ref.read(notesProvider.notifier).updateNote(updatedEvent);
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF5473F7),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                    ),
                                    child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    final currentEvent = notesAsync.value?.firstWhere(
          (n) => n.id == widget.event.id,
          orElse: () => widget.event,
        ) ?? widget.event;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: _buildCompleteButton(currentEvent),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black),
            onPressed: () => _showDeleteDialog(context, currentEvent),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _editTitle,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (currentEvent.color != null)
                      Container(
                        width: 12,
                        height: 38,
                        margin: const EdgeInsets.only(top: 4, right: 16),
                        decoration: BoxDecoration(
                          color: Color(currentEvent.color!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        currentEvent.title,
                        style: GoogleFonts.roboto(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildDateTimeCard(currentEvent),
              const SizedBox(height: 32),

              Text(
                'DESCRIPTION',
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),

              _buildDescriptionBox(currentEvent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteButton(Note event) {
    final isCompleted = event.isCompleted;
    return GestureDetector(
      onTap: () {
        ref.read(notesProvider.notifier).toggleCompleted(event.id);
        Navigator.pop(context); // Go back immediately to daily timeline
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF5372F6),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isCompleted ? const Color(0xFF10B981) : const Color(0xFF5372F6))
                  .withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.circle_outlined,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isCompleted ? 'Event Completed' : 'Complete Event',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeCard(Note event) {
    final dateStr = event.scheduledTime != null ? DateFormat('MMM d, yyyy').format(event.scheduledTime!) : 'No date';
    final startTimeStr = event.scheduledTime != null ? DateFormat('h:mm a').format(event.scheduledTime!) : 'Set start';
    final endTimeStr = event.endTime != null ? DateFormat('h:mm a').format(event.endTime!) : '';

    final timeDisplay = event.isAllDay ? 'All Day' : (endTimeStr.isNotEmpty ? '$startTimeStr - $endTimeStr' : startTimeStr);

    return GestureDetector(
      onTap: _openTimePlannerSheet,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF5372F6)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      dateStr,
                      style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1F2937)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                timeDisplay,
                textAlign: TextAlign.right,
                style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1F2937)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionBox(Note event) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: TextField(
        controller: _descriptionController,
        maxLines: null,
        style: GoogleFonts.roboto(
          fontSize: 15,
          color: const Color(0xFF374151),
          height: 1.5,
        ),
        decoration: const InputDecoration(
          hintText: 'Add details or notes...',
          hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          filled: false,
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Note event) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Event'),
            content: const Text('Are you sure you want to delete this event?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(notesProvider.notifier).deleteNote(event.id);
                  Navigator.pop(dialogContext); // close dialog using its own context
                  if (context.mounted) {
                    Navigator.pop(context); // close view page using the parent context
                  }
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
