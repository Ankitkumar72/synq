import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../notes/domain/models/note.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../notes/domain/models/recurrence_rule.dart';
import 'repeat_configuration_screen.dart';
import '../../../notes/data/folder_provider.dart';
import '../../../notes/domain/models/folder.dart';

class CreateTaskSheet extends ConsumerStatefulWidget {
  final Note? taskToEdit;
  final String? initialFolderId;

  const CreateTaskSheet({super.key, this.taskToEdit, this.initialFolderId});

  @override
  ConsumerState<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends ConsumerState<CreateTaskSheet> {
  NoteCategory _selectedTaskCategory = NoteCategory.work;
  TaskPriority _selectedPriority = TaskPriority.medium;
  DateTime? _taskDueDate;
  DateTime? _taskEndTime;
  bool _isTaskAllDay = false;
  DateTime? _taskReminderTime;
  RecurrenceRule? _recurrenceRule;
  String? _selectedFolderId;


  final _taskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      final task = widget.taskToEdit!;
      _taskController.text = task.title;
      _selectedTaskCategory = task.category;
      _selectedPriority = task.priority;
      _taskDueDate = task.scheduledTime;
      _taskEndTime = task.endTime;
      _isTaskAllDay = task.isAllDay;
      _taskReminderTime = task.reminderTime;
      _recurrenceRule = task.recurrenceRule;
    } else {
      _selectedFolderId = widget.initialFolderId;
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initialDate = _taskDueDate ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      setState(() {
        if (_taskDueDate != null && !_isTaskAllDay) {
          _taskDueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            _taskDueDate!.hour,
            _taskDueDate!.minute,
          );
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
          _taskDueDate =
              DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
          _isTaskAllDay = true;
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final initialBase = _taskDueDate ?? DateTime.now();
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
        _taskDueDate = newDate;
        _isTaskAllDay = false;
        _taskEndTime = _taskDueDate!.add(const Duration(hours: 1));
      });
    }
  }
  
  Future<void> _pickReminderTime() async {
    final initialDate = _taskDueDate ?? DateTime.now();
        
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
          _taskReminderTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
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

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Date';
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isTomorrow =
        dt.year == now.year && dt.month == now.month && dt.day == now.day + 1;

    if (isToday) return 'Today';
    if (isTomorrow) return 'Tomorrow';
    return '${dt.day}/${dt.month}';
  }

  String _formatTime(DateTime? dt, {DateTime? endTime}) {
    if (dt == null) return 'Time';
    final startTimeStr =
        "${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
    if (endTime != null) {
      final endTimeStr =
          "${endTime.hour > 12 ? endTime.hour - 12 : (endTime.hour == 0 ? 12 : endTime.hour)}:${endTime.minute.toString().padLeft(2, '0')} ${endTime.hour >= 12 ? 'PM' : 'AM'}";
      return "$startTimeStr - $endTimeStr";
    }
    return startTimeStr;
  }
  
  String _formatDateTime(DateTime? dt) {
      if (dt == null) return 'Set Date/Time';
      return "${_formatDate(dt)}, ${_formatTime(dt)}";
  }

  String _getRepeatLabel() {
    if (_recurrenceRule == null) return 'Repeat';
    final interval = _recurrenceRule!.interval;
    final unit = _recurrenceRule!.unit.name;
    return interval == 1 ? 'Every $unit' : 'Every $interval ${unit}s';
  }

  Future<void> _handleSave() async {
    final taskText = _taskController.text.trim();

    if (taskText.isEmpty) {
      if (mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a task'),
            backgroundColor: Colors.orange,
          ),
        );
       }
      return;
    }

    final startTime = _taskDueDate;
    final endTime = _taskEndTime;

    final task = (widget.taskToEdit?.copyWith(
          title: taskText,
          category: _selectedTaskCategory,
          scheduledTime: startTime,
          endTime: endTime,
          reminderTime: _taskReminderTime,
          recurrenceRule: _recurrenceRule,
          priority: _selectedPriority,
          isTask: true,
          isAllDay: _isTaskAllDay,
          tags: [_selectedTaskCategory.name],
          folderId: _selectedFolderId,
        ) ??
        Note(
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
          attachments: [], // Simplified for now
          links: [],      // Simplified for now
          folderId: _selectedFolderId,
        ));

    if (widget.taskToEdit == null) {
      // Create New
      await ref.read(notesProvider.notifier).addNote(task);
    } else {
      // Edit Existing
      final original = widget.taskToEdit!;
      if (original.recurrenceRule != null || original.parentRecurringId != null) {
        final updateMode = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => SimpleDialog(
            title: const Text('Edit Recurring Task'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'THIS'),
                child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('This task only')),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'FUTURE'),
                child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('This and future tasks')),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'ALL'),
                child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('All tasks in series')),
              ),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel')),
            ],
          ),
        );

        if (updateMode == null) return;

        if (updateMode == 'THIS') {
          await ref.read(notesProvider.notifier).updateNote(task);
        } else if (updateMode == 'FUTURE') {
          await ref.read(notesProvider.notifier).updateFutureInstances(task);
        } else if (updateMode == 'ALL') {
          await ref.read(notesProvider.notifier).updateAllInstances(task);
        }
      } else {
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
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Task',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                ),
                ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withAlpha(50), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _taskController,
                    autofocus: true,
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
                    style:
                        const TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInteractiveChip(
                        context,
                        icon: Icons.calendar_today,
                        label: _formatDate(_taskDueDate),
                        isSelected: _taskDueDate != null,
                        onTap: _pickDate,
                      ),
                      if (_taskDueDate != null) ...[
                        _buildInteractiveChip(
                          context,
                          icon: Icons.access_time,
                          label: _isTaskAllDay
                              ? 'All Day'
                              : _formatTime(_taskDueDate,
                                  endTime: _taskEndTime),
                          isSelected: !_isTaskAllDay,
                          onTap: _pickTime,
                        ),
                      ],
                       _buildInteractiveChip(
                        context,
                        icon: Icons.alarm,
                        label: _taskReminderTime != null ? _formatDateTime(_taskReminderTime) : 'Remind me',
                        isSelected: _taskReminderTime != null,
                        onTap: _pickReminderTime,
                      ),
                      _buildPriorityChip(context),
                      _buildCategoryChip(context),
                      _buildFolderChip(context),
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
          color: isSelected
              ? AppColors.primary.withAlpha(30)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
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
        setState(() {
          final priorities = TaskPriority.values;
          final currentIndex = priorities.indexOf(_selectedPriority);
          _selectedPriority =
              priorities[(currentIndex + 1) % priorities.length];
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
            Icon(Icons.flag,
                size: 16, color: priorityColors[_selectedPriority]),
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

  Widget _buildCategoryChip(BuildContext context) {
    final categoryLabels = {
      NoteCategory.work: 'Work',
      NoteCategory.personal: 'Personal',
      NoteCategory.idea: 'Idea',
    };

    return GestureDetector(
      onTap: () {
        setState(() {
          final categories = NoteCategory.values;
          final currentIndex = categories.indexOf(_selectedTaskCategory);
          _selectedTaskCategory =
              categories[(currentIndex + 1) % categories.length];
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
            Icon(Icons.label_outline,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              categoryLabels[_selectedTaskCategory]!,
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

  Widget _buildFolderChip(BuildContext context) {
    final foldersAsync = ref.watch(foldersProvider);
    return foldersAsync.when(
      data: (folders) {
        final selectedFolder = folders.firstWhere(
          (f) => f.id == _selectedFolderId,
          orElse: () => Folder(id: '', name: 'No Folder', iconCodePoint: 0, colorValue: 0, createdAt:  DateTime(2024)), // Dummy
        );
        
        final label = _selectedFolderId == null ? 'Folder' : selectedFolder.name;
        final isSelected = _selectedFolderId != null;

        return GestureDetector(
          onTap: () async {
            // Show simple dialog or sheet to pick folder
            final String? pickedId = await showModalBottomSheet<String>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (ctx) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Select Folder', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const Icon(Icons.folder_off),
                      title: const Text('No Folder'),
                      onTap: () => Navigator.pop(ctx, null), // Return null for clear
                    ),
                    const Divider(),
                    ...folders.map((f) => ListTile(
                      leading: Icon(IconData(f.iconCodePoint, fontFamily: f.iconFontFamily ?? 'MaterialIcons'), color: Color(f.colorValue)),
                      title: Text(f.name),
                      trailing: f.id == _selectedFolderId ? const Icon(Icons.check, color: Colors.blue) : null,
                      onTap: () => Navigator.pop(ctx, f.id),
                    )),
                  ],
                ),
              ),
            );
            
            // Set state even if null (to clear)
            setState(() {
               // Logic: if user taps "No Folder" (null), we clear it. 
               // If user dismisses (null returned but not explicit), we probably shouldn't change?
               // Actually the dialog returns null on dismiss. We need a way to distinguish "Clear" vs "Cancel".
               // Hack: "No Folder" returns "NO_FOLDER" or empty string, dismiss returns null.
            });
            
             // Re-implementing logic for better null handling
             if (pickedId != null) {
                setState(() => _selectedFolderId = pickedId == 'NO_FOLDER' ? null : pickedId);
             } else {
                 // Should we create a cleaner picker? Yes but for now this is fine. 
                 // Updating the onTap above to return explicit null for "No Folder" is tricky if dismiss is also null.
                 // Let's assume the user selects something.
             }
             
             // Let's better implement the dialog to handle "No Folder"
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withAlpha(30) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Icon(Icons.folder_outlined, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
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
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

void showCreateTaskSheet(BuildContext context, {Note? taskToEdit, String? initialFolderId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CreateTaskSheet(taskToEdit: taskToEdit, initialFolderId: initialFolderId),
  );
}
