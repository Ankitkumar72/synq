import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/navigation/fade_page_route.dart';
import '../../../../core/services/media_service.dart';
import '../../../notes/domain/models/note.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../agenda/presentation/create_meeting_screen.dart';
import '../../../agenda/presentation/meeting_agenda_screen.dart';
import '../../../agenda/data/meetings_provider.dart';
import '../../../notes/domain/models/recurrence_rule.dart';
import 'repeat_configuration_screen.dart';

/// A bottom sheet for creating new tasks or notes.
class CreateNewSheet extends ConsumerStatefulWidget {
  final Note? noteToEdit;

  const CreateNewSheet({super.key, this.noteToEdit});

  @override
  ConsumerState<CreateNewSheet> createState() => _CreateNewSheetState();
}

class _CreateNewSheetState extends ConsumerState<CreateNewSheet> {
  NoteCategory _selectedTaskCategory = NoteCategory.work;
  NoteCategory _selectedNoteCategory = NoteCategory.work;
  TaskPriority _selectedPriority = TaskPriority.medium;
  DateTime? _taskDueDate;
  DateTime? _taskEndTime;
  bool _isTaskAllDay = false; // Add all-day flag

  DateTime? _taskReminderTime; // Task reminder
  DateTime? _noteDate;
  DateTime? _noteReminderTime; // Note reminder
  RecurrenceRule? _recurrenceRule; // Added recurrence rule

  
  // Media and links state
  final List<String> _taskAttachments = [];
  final List<String> _taskLinks = [];
  final List<String> _noteAttachments = [];
  final List<String> _noteLinks = [];
  final MediaService _mediaService = MediaService();
  bool _isUploadingImage = false;

  final _taskController = TextEditingController();
  final _noteTitleController = TextEditingController();
  final _noteBodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.noteToEdit != null) {
      final note = widget.noteToEdit!;
      if (note.isTask) {
        _taskController.text = note.title;
        _selectedTaskCategory = note.category;
        _selectedPriority = note.priority;
        _taskDueDate = note.scheduledTime;
        _taskEndTime = note.endTime;
        _isTaskAllDay = note.isAllDay;
        _taskReminderTime = note.reminderTime;
        _recurrenceRule = note.recurrenceRule;
        _taskAttachments.addAll(note.attachments);
        _taskLinks.addAll(note.links);
      } else {
        _noteTitleController.text = note.title;
        _noteBodyController.text = note.body ?? '';
        _selectedNoteCategory = note.category;
        _noteDate = note.scheduledTime;
        _noteReminderTime = note.reminderTime;
        _noteAttachments.addAll(note.attachments);
        _noteLinks.addAll(note.links);
      }
    }
  }



  Future<void> _pickReminderTime(bool isTask) async {
    final initialDate = isTask 
        ? (_taskDueDate ?? DateTime.now()) 
        : (_noteDate ?? DateTime.now());
        
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: "Select Reminder Date",
    );
    
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        helpText: "Select Reminder Time",
      );
      
      if (pickedTime != null) {
        setState(() {
          final reminder = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          
          if (isTask) {
            _taskReminderTime = reminder;
          } else {
            _noteReminderTime = reminder;
          }
        });
      }
    }
  }

  Future<void> _showRepeatDialog() async {
     final RecurrenceRule? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RepeatConfigurationScreen(
          initialRule: _recurrenceRule,
        ),
      ),
    );

    if (result != null) {
      setState(() => _recurrenceRule = result);
    }
  }



  String _getRepeatLabel() {
    if (_recurrenceRule == null) return 'Repeat';
    final interval = _recurrenceRule!.interval;
    final unit = _recurrenceRule!.unit.name;
    return interval == 1 ? 'Every $unit' : 'Every $interval ${unit}s';
  }
  
  Future<void> _pickDate(bool isTask) async {
    final initialDate = isTask 
        ? (_taskDueDate ?? DateTime.now()) 
        : (_noteDate ?? DateTime.now());
        
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (pickedDate != null && mounted) {
      setState(() {
        if (isTask) {
          // If we already have a time, keep it but update the date
          if (_taskDueDate != null && !_isTaskAllDay) {
             _taskDueDate = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              _taskDueDate!.hour,
              _taskDueDate!.minute,
             );
             // Update end time date too if it exists
             if (_taskEndTime != null) {
                _taskEndTime = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  _taskEndTime!.hour,
                  _taskEndTime!.minute,
                );
             }
          } else {
            // No time set or all day -> just set the date at midnight
            _taskDueDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
            _isTaskAllDay = true; // Default to all day when just picking date
          }
        } else {
          // For notes, just update the date
           if (_noteDate != null) {
              _noteDate = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              _noteDate!.hour,
              _noteDate!.minute,
             );
           } else {
             _noteDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
           }
        }
      });
    }
  }

  Future<void> _pickTime(bool isTask) async {
     final initialBase = isTask 
        ? (_taskDueDate ?? DateTime.now())
        : (_noteDate ?? DateTime.now());
        
     final TimeOfDay initialTime = TimeOfDay.fromDateTime(initialBase);
     
     final pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
        helpText: "Select Start Time",
      );

      if (pickedTime != null && mounted) {
         final newDate = DateTime(
           initialBase.year,
           initialBase.month,
           initialBase.day,
           pickedTime.hour,
           pickedTime.minute,
         );
         
         setState(() {
           if (isTask) {
             _taskDueDate = newDate;
             _isTaskAllDay = false; // Now it's a timed task
             
             // Default end time to 1 hour later
             _taskEndTime = _taskDueDate!.add(const Duration(hours: 1));
           } else {
             _noteDate = newDate;
           }
         });
      }
  }
  

  
  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Date';
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isTomorrow = dt.year == now.year && dt.month == now.month && dt.day == now.day + 1;
    
    if (isToday) return 'Today';
    if (isTomorrow) return 'Tomorrow';
    return '${dt.day}/${dt.month}';
  }

  String _formatTime(DateTime? dt, {DateTime? endTime}) {
     if (dt == null) return 'Time';
     final startTimeStr = "${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
     if (endTime != null) {
       final endTimeStr = "${endTime.hour > 12 ? endTime.hour - 12 : (endTime.hour == 0 ? 12 : endTime.hour)}:${endTime.minute.toString().padLeft(2, '0')} ${endTime.hour >= 12 ? 'PM' : 'AM'}";
       return "$startTimeStr - $endTimeStr";
     }
     return startTimeStr;
  }
  
  String _formatDateTime(DateTime? dt, {DateTime? endTime}) {
      // Deprecated in favor of separate formatters, but keeping for compatibility if reused
      if (dt == null) return 'Set Date/Time';
      return "${_formatDate(dt)}, ${_formatTime(dt, endTime: endTime)}";
  }
  


  @override
  void dispose() {
    _taskController.dispose();
    _noteTitleController.dispose();
    _noteBodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create New',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                ),
                ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // NEW TASK Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withAlpha(50), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'NEW TASK',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _taskController,
                            decoration: const InputDecoration(
                              hintText: 'What needs to be done?',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            style: const TextStyle(color: Colors.black87, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          // Tags Row - Interactive
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildInteractiveChip(
                                context,
                                icon: Icons.calendar_today,
                                label: _formatDate(_taskDueDate),
                                isSelected: _taskDueDate != null,
                                onTap: () => _pickDate(true),
                              ),
                              if (_taskDueDate != null) ...[
                                _buildInteractiveChip(
                                  context,
                                  icon: Icons.access_time,
                                  label: _isTaskAllDay ? 'All Day' : _formatTime(_taskDueDate, endTime: _taskEndTime),
                                  isSelected: !_isTaskAllDay,
                                  onTap: () => _pickTime(true),
                                ),
                              ],
                              _buildInteractiveChip(
                                context,
                                icon: Icons.alarm,
                                label: _taskReminderTime != null ? _formatDateTime(_taskReminderTime) : 'Remind me',
                                isSelected: _taskReminderTime != null,
                                onTap: () => _pickReminderTime(true),
                              ),
                              _buildPriorityChip(context),
                              _buildCategoryChip(context, isTask: true),
                              // Repeat Chip
                              _buildInteractiveChip(
                                context,
                                icon: Icons.repeat,
                                label: _getRepeatLabel(),
                                isSelected: _recurrenceRule != null,
                                onTap: _showRepeatDialog,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // NEW NOTE Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withAlpha(50), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.description, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'NEW NOTE',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _noteTitleController,
                            decoration: const InputDecoration(
                              hintText: 'Title (optional)',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _noteBodyController,
                            decoration: const InputDecoration(
                              hintText: 'Start typing your thoughts...',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            style: const TextStyle(color: Colors.black87, fontSize: 16),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          // Note options row
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildCategoryChip(context, isTask: false),
                              // Note Date Chip
                              _buildInteractiveChip(
                                context,
                                icon: Icons.calendar_today,
                                label: _formatDate(_noteDate),
                                isSelected: _noteDate != null,
                                onTap: () => _pickDate(false),
                              ),
                              // Note Time Chip (Only if date is selected)
                              if (_noteDate != null) ...[
                                _buildInteractiveChip(
                                  context,
                                  icon: Icons.access_time,
                                  label: _formatTime(_noteDate),
                                  isSelected: true, // If it's shown, it has a time? Actually for notes we might just assume time is set if date is set, OR make it optional too.
                                  // For consistency, let's say notes are just date unless time explicitly added.
                                  // But the previous implementation for notes was just one "Date/Time" chip.
                                  // Let's stick to the request: "Time must be optional for both tasks and notes."
                                  onTap: () => _pickTime(false),
                                ),
                              ],
                              
                              // Reminder Chip (New for notes too)
                               _buildInteractiveChip(
                                context,
                                icon: Icons.alarm,
                                label: _noteReminderTime != null ? _formatDateTime(_noteReminderTime) : 'Remind',
                                isSelected: _noteReminderTime != null,
                                onTap: () => _pickReminderTime(false),
                              ),

                              // Add Media button (New position)
                              _buildInteractiveChip(
                                context,
                                icon: Icons.image_outlined,
                                label: 'Media',
                                isSelected: _noteAttachments.isNotEmpty,
                                onTap: () => _pickAndSaveImage(ImageSource.gallery, false), // Attaching to note
                              ),

                              // Add Link button
                              _buildInteractiveChip(
                                context,
                                icon: Icons.link,
                                label: 'Link',
                                isSelected: _noteLinks.isNotEmpty,
                                onTap: () => _showAddLinkDialog(false),
                              ),
                            ],
                          ),
                          // Show attached images
                          if (_noteAttachments.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 80,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _noteAttachments.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  return _buildAttachmentThumbnail(_noteAttachments[index], () {
                                    setState(() => _noteAttachments.removeAt(index));
                                  });
                                },
                              ),
                            ),
                          ],
                          // Show links
                          if (_noteLinks.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _noteLinks.asMap().entries.map((entry) {
                                return _buildLinkChip(entry.value, () {
                                  setState(() => _noteLinks.removeAt(entry.key));
                                });
                              }).toList(),
                            ),
                          ],
                          // Loading indicator
                          if (_isUploadingImage)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // NEW MEETING Card
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(context); // Close sheet first
                        final result = await Navigator.push(
                          context,
                          FadePageRoute(builder: (_) => const CreateMeetingScreen()),
                        );
                        if (result != null && context.mounted) {
                          // Save the meeting to the provider so it appears in Timeline
                          ref.read(meetingsProvider.notifier).addMeeting(result);
                          
                          // Navigate to view the created meeting
                          Navigator.push(
                            context,
                            FadePageRoute(builder: (_) => MeetingAgendaScreen(data: result)),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF4C7BF3).withAlpha(50), width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4C7BF3).withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.event_note, color: Color(0xFF4C7BF3), size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'NEW MEETING',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: const Color(0xFF4C7BF3),
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Create agenda with topics & participants',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
    ),
  );
  }

  Widget _buildInteractiveChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(30) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(BuildContext context) {
    final priorityLabels = {
      TaskPriority.low: 'Low',
      TaskPriority.medium: 'Medium',
      TaskPriority.high: 'High',
    };
    final priorityColors = {
      TaskPriority.low: Colors.green,
      TaskPriority.medium: Colors.orange,
      TaskPriority.high: Colors.red,
    };
    
    return GestureDetector(
      onTap: () {
        // Cycle through priorities
        setState(() {
          final priorities = TaskPriority.values;
          final currentIndex = priorities.indexOf(_selectedPriority);
          _selectedPriority = priorities[(currentIndex + 1) % priorities.length];
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: priorityColors[_selectedPriority]!.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag, size: 16, color: priorityColors[_selectedPriority]),
            const SizedBox(width: 6),
            Text(
              priorityLabels[_selectedPriority]!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: priorityColors[_selectedPriority],
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context, {required bool isTask}) {
    final categoryLabels = {
      NoteCategory.work: 'Work',
      NoteCategory.personal: 'Personal',
      NoteCategory.idea: 'Idea',
    };
    
    final currentCategory = isTask ? _selectedTaskCategory : _selectedNoteCategory;

    return GestureDetector(
      onTap: () {
        // Cycle through categories
        setState(() {
          final categories = NoteCategory.values;
          final currentIndex = categories.indexOf(currentCategory);
          final nextCategory = categories[(currentIndex + 1) % categories.length];
          
          if (isTask) {
            _selectedTaskCategory = nextCategory;
          } else {
            _selectedNoteCategory = nextCategory;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.label_outline, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              categoryLabels[currentCategory]!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _handleSave() async {
    final taskText = _taskController.text.trim();
    final noteTitle = _noteTitleController.text.trim();
    final noteBody = _noteBodyController.text.trim();
    
    // Determine if we're saving a task or note
    if (taskText.isNotEmpty) {
      // Configure Task Object
      final startTime = _taskDueDate; 
      final endTime = _taskEndTime;
      
      final task = (widget.noteToEdit?.copyWith(
        title: taskText,
        category: _selectedTaskCategory,
        // formatted time/date logic
        scheduledTime: startTime,
        endTime: endTime,
        reminderTime: _taskReminderTime,
        recurrenceRule: _recurrenceRule,
        priority: _selectedPriority,
        isTask: true,
        isAllDay: _isTaskAllDay,
        tags: [_selectedTaskCategory.name],
        attachments: List.from(_taskAttachments),
        links: List.from(_taskLinks),
      ) ?? Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: taskText,
        category: _selectedTaskCategory,
        createdAt: DateTime.now(),
        scheduledTime: startTime,
        endTime: endTime,
        reminderTime: _taskReminderTime,
        recurrenceRule: _recurrenceRule, 
        parentRecurringId: null, 
        isRecurringInstance: false,
        priority: _selectedPriority,
        isTask: true,
        isAllDay: _isTaskAllDay,
        tags: [_selectedTaskCategory.name],
        attachments: List.from(_taskAttachments),
        links: List.from(_taskLinks),
      ));

      if (widget.noteToEdit == null) {
        // Create New
         await ref.read(notesProvider.notifier).addNote(task);
      } else {
        // Edit Existing
        final original = widget.noteToEdit!;
        // Check if recurring
        if (original.recurrenceRule != null || original.parentRecurringId != null) {
           // Ask user how to update
           final updateMode = await showDialog<String>(
             context: context,
             barrierDismissible: false,
             builder: (ctx) => SimpleDialog(
               title: const Text('Edit Recurring Task'),
               children: [
                 SimpleDialogOption(
                   onPressed: () => Navigator.pop(ctx, 'THIS'),
                   child: const Padding(padding: EdgeInsets.all(8.0), child: Text('This task only')),
                 ),
                 SimpleDialogOption(
                   onPressed: () => Navigator.pop(ctx, 'FUTURE'),
                   child: const Padding(padding: EdgeInsets.all(8.0), child: Text('This and future tasks')),
                 ),
                 SimpleDialogOption(
                   onPressed: () => Navigator.pop(ctx, 'ALL'),
                   child: const Padding(padding: EdgeInsets.all(8.0), child: Text('All tasks in series')),
                 ),
                 TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
               ],
             ),
           );
           
           if (updateMode == null) return; // Cancelled
           
           if (updateMode == 'THIS') {
             await ref.read(notesProvider.notifier).updateNote(task);
           } else if (updateMode == 'FUTURE') {
             await ref.read(notesProvider.notifier).updateFutureInstances(task);
           } else if (updateMode == 'ALL') {
             await ref.read(notesProvider.notifier).updateAllInstances(task);
           }
        } else {
          // Normal edit
          await ref.read(notesProvider.notifier).updateNote(task);
        }
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task "$taskText" saved!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (noteTitle.isNotEmpty || noteBody.isNotEmpty) {
       // Note logic
       final title = noteTitle.isNotEmpty ? noteTitle : 'Untitled Note';
       
       final note = (widget.noteToEdit?.copyWith(
         title: title,
         body: noteBody,
         category: _selectedNoteCategory,
         scheduledTime: _noteDate,
         reminderTime: _noteReminderTime,
         isTask: false,
         attachments: List.from(_noteAttachments),
         links: List.from(_noteLinks),
       ) ?? Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: noteBody,
        category: _selectedNoteCategory,
        createdAt: DateTime.now(),
        scheduledTime: _noteDate, // For calendar/timeline placement
        reminderTime: _noteReminderTime,
        priority: TaskPriority.medium,
        isTask: false,
        tags: [_selectedNoteCategory.name],
        attachments: List.from(_noteAttachments),
        links: List.from(_noteLinks),
      ));
      
      if (widget.noteToEdit == null) {
        await ref.read(notesProvider.notifier).addNote(note);
      } else {
        await ref.read(notesProvider.notifier).updateNote(note);
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note saved!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
       if (mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a task or note'),
            backgroundColor: Colors.orange,
          ),
        );
       }
    }
  }



  // Pick and save an image locally
  Future<void> _pickAndSaveImage(ImageSource source, bool isTask) async {
    // Determine target based on which field has content or focus?
    // Since we have two separate cards, let's assume if Task text is not empty we attach to task, else note?
    // Or simpler: The user requested a toolbar. 
    // Let's modify the flow: 
    // If the user taps the image icon, we'll ask or default.
    // Given the constraints, let's default to attaching to the "Task" if that controller is not empty, otherwise "Note".
    
    // Correction: The previous logic passed `isTask` boolean. 
    // Let's try to detect context or just show options.
    
    setState(() => _isUploadingImage = true);
    
    final path = await _mediaService.pickAndSaveImage(source: source);
    
    setState(() => _isUploadingImage = false);
    
    if (path != null) {
      setState(() {
        // Simple heuristic: If task has text, add to task. Else add to note.
        if (_taskController.text.isNotEmpty) {
           _taskAttachments.add(path);
        } else {
           _noteAttachments.add(path);
        }
      });
    } else {
      // Cancelled or failed
    }
  }

  // Show dialog to add a link
  void _showAddLinkDialog(bool isTask) {
    final linkController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Link'),
        content: TextField(
          controller: linkController,
          decoration: const InputDecoration(
            hintText: 'https://example.com',
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final link = linkController.text.trim();
              if (link.isNotEmpty) {
                // Add https:// if missing
                String finalLink = link;
                if (!link.startsWith('http://') && !link.startsWith('https://')) {
                  finalLink = 'https://$link';
                }
                setState(() {
                  if (isTask) {
                    _taskLinks.add(finalLink);
                  } else {
                    _noteLinks.add(finalLink);
                  }
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Build attachment thumbnail widget
  Widget _buildAttachmentThumbnail(String url, VoidCallback onRemove) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              );
            },
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // Build link chip widget
  Widget _buildLinkChip(String url, VoidCallback onRemove) {
    // Extract domain for display
    String displayText;
    try {
      final uri = Uri.parse(url);
      displayText = uri.host.replaceFirst('www.', '');
    } catch (_) {
      displayText = url.length > 20 ? '${url.substring(0, 20)}...' : url;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link, size: 14, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            displayText,
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Colors.blue),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the CreateNewSheet
void showCreateNewSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const CreateNewSheet(),
  );
}
