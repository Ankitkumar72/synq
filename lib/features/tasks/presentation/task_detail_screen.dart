import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../notes/domain/models/note.dart';
import '../../notes/data/notes_provider.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final Note task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late TextEditingController _subTaskController;
  late TextEditingController _descriptionController;
  late FocusNode _subTaskFocusNode;
  bool _isAddingSubTask = false;

  Note get _currentTask {
    final notes = ref.read(notesProvider).value;
    return notes?.firstWhere((n) => n.id == widget.task.id, orElse: () => widget.task) ?? widget.task;
  }

  @override
  void initState() {
    super.initState();
    _subTaskController = TextEditingController();
    _descriptionController = TextEditingController(text: widget.task.body);
    _subTaskFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _subTaskController.dispose();
    _descriptionController.dispose();
    _subTaskFocusNode.dispose();
    super.dispose();
  }

  void _toggleTaskCompletion() {
    ref.read(notesProvider.notifier).toggleCompleted(_currentTask.id);
    Navigator.pop(context);
  }

  void _addSubTask() {
    if (_subTaskController.text.trim().isEmpty) return;

    final newSubTask = SubTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _subTaskController.text.trim(),
      isCompleted: false,
    );

    final updatedTask = _currentTask.copyWith(
      subtasks: [..._currentTask.subtasks, newSubTask],
    );

    ref.read(notesProvider.notifier).updateNote(updatedTask);
    
    // Clear the controller to prepare for the next item
    _subTaskController.clear();
    
    // Keep the UI in adding mode and ensure focus stays on the input
    // effectively creating a "new line" in the list
    setState(() {
      // Logic relies on state update to reflect the new item in the list above
    });

    // Request focus back to the text field to continue typing immediately
    _subTaskFocusNode.requestFocus();
  }

  void _toggleSubTask(String subTaskId) {
    final updatedSubtasks = _currentTask.subtasks.map((st) {
      if (st.id == subTaskId) {
        return st.copyWith(isCompleted: !st.isCompleted);
      }
      return st;
    }).toList();

    final updatedTask = _currentTask.copyWith(subtasks: updatedSubtasks);
    ref.read(notesProvider.notifier).updateNote(updatedTask);
  }

  void _editTitle() {
    final currentTask = _currentTask;
    final controller = TextEditingController(text: currentTask.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.black87),
          cursorColor: AppColors.primary,
          decoration: const InputDecoration(
            hintText: 'Enter task title',
             hintStyle: TextStyle(color: Colors.grey),
            border: OutlineInputBorder(),
             enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
            filled: true,
            fillColor: Colors.white,
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
                 final updatedTask = currentTask.copyWith(title: newTitle);
                 ref.read(notesProvider.notifier).updateNote(updatedTask);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final currentTask = _currentTask;
    final initialDate = currentTask.scheduledTime ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final currentScheduled = currentTask.scheduledTime ?? DateTime.now();
      final newScheduled = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        currentScheduled.hour,
        currentScheduled.minute,
      );
      
      final updatedTask = currentTask.copyWith(scheduledTime: newScheduled);
      ref.read(notesProvider.notifier).updateNote(updatedTask);
    }
  }

  Future<void> _pickTime() async {
    final currentTask = _currentTask;
    final initialDate = currentTask.scheduledTime ?? DateTime.now();
    final initialTime = TimeOfDay.fromDateTime(initialDate);

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime != null) {
      final newScheduled = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      final updatedTask = currentTask.copyWith(scheduledTime: newScheduled);
      ref.read(notesProvider.notifier).updateNote(updatedTask);
    }
  }

  void _deleteTask() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(notesProvider.notifier).deleteNote(_currentTask.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes to the specific task
    final notesAsync = ref.watch(notesProvider);
    final taskOrNull = notesAsync.value?.firstWhere(
      (n) => n.id == widget.task.id, 
      orElse: () => widget.task
    );
    
    // If task was deleted, pop
    if (taskOrNull == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
      });
      return const SizedBox.shrink(); 
    }
    
    final task = taskOrNull;
    final completedSubtasks = task.subtasks.where((s) => s.isCompleted).length;
    final totalSubtasks = task.subtasks.length;
    final progress = totalSubtasks > 0 ? completedSubtasks / totalSubtasks : 0.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            onSelected: (value) {
              if (value == 'delete') {
                _deleteTask();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Task', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ];
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            GestureDetector(
              onTap: _editTitle,
              child: Text(
                task.title,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Date & Time Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _pickDate,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF5372F6)),
                        const SizedBox(width: 8),
                        _DateDisplay(scheduledTime: task.scheduledTime),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickTime,
                      behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 18, color: Color(0xFF5372F6)),
                        const SizedBox(width: 8),
                        _TimeDisplay(scheduledTime: task.scheduledTime),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Description - Persistent Card
            const _SectionTitle(title: 'DESCRIPTION'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _descriptionController,
                    maxLines: null,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1F2937),
                        height: 1.5,
                      ),
                    decoration: const InputDecoration(
                      hintText: 'Add details or notes...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      filled: false,
                      fillColor: Colors.transparent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                          final newBody = _descriptionController.text.trim();
                          if (newBody != (task.body ?? '')) {
                            final updatedTask = task.copyWith(body: newBody);
                            ref.read(notesProvider.notifier).updateNote(updatedTask);
                          }
                          FocusScope.of(context).unfocus();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFE0E7FF), // Light indigo bg
                        foregroundColor: const Color(0xFF4F46E5), // Indigo text
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tags
            if (task.tags.isNotEmpty) ...[
              const _SectionTitle(title: 'TAGS'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: task.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Sub-tasks Section
            const _SectionTitle(title: 'SUB-TASKS'),
            const SizedBox(height: 12),
            
            if (task.subtasks.isEmpty && !_isAddingSubTask)
              GestureDetector(
                onTap: () => setState(() => _isAddingSubTask = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.playlist_add, color: Color(0xFF5372F6), size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Add Sub-tasks',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress
                    if (totalSubtasks > 0) ...[
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: const AlwaysStoppedAnimation(Color(0xFF4AC299)),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Color(0xFF4AC299),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                    ],

                    // Existing Subtasks
                    ...task.subtasks.map((subtask) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _toggleSubTask(subtask.id),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: subtask.isCompleted ? const Color(0xFF6B8AFD) : Colors.transparent, 
                                borderRadius: BorderRadius.circular(12), // Circle
                                border: subtask.isCompleted ? null : Border.all(color: Colors.grey[300]!, width: 2),
                              ),
                              child: subtask.isCompleted 
                                  ? const Icon(Icons.check, size: 14, color: Colors.white) 
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              subtask.title,
                              style: TextStyle(
                                fontSize: 15,
                                color: subtask.isCompleted ? const Color(0xFF9CA3AF) : const Color(0xFF374151),
                                decoration: subtask.isCompleted ? TextDecoration.lineThrough : null,
                                decorationColor: const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),

                    // Add Subtask Row - Simplified for "List" feel
                    Row(
                      children: [
                        Container(
                          width: 24, 
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[300]!, width: 2),
                          ),
                          child: const Icon(Icons.add, size: 14, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _subTaskController,
                            focusNode: _subTaskFocusNode,
                            autofocus: true,
                            textInputAction: TextInputAction.done, 
                            style: const TextStyle(fontSize: 15, color: Colors.black),
                            cursorColor: AppColors.primary,
                            decoration: const InputDecoration(
                              hintText: 'Add a sub-task...',
                              hintStyle: TextStyle(color: Colors.black54),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            onSubmitted: (_) => _addSubTask(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF5372F6), size: 24),
                          onPressed: _addSubTask,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Attachments
            // Force rebuild
            if (task.attachments.isNotEmpty) ...[
              const _SectionTitle(title: 'ATTACHMENTS'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                      ...task.attachments.map((url) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                        ),
                      ))
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleTaskCompletion,
        backgroundColor: const Color(0xFF5372F6),
        icon: Icon(
          task.isCompleted ? Icons.check_circle : Icons.circle_outlined, 
          color: Colors.white
        ),
        label: Text(
          task.isCompleted ? 'Task Completed' : 'Complete Task',
          style: const TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _DateDisplay extends StatelessWidget {
  final DateTime? scheduledTime;

  const _DateDisplay({this.scheduledTime});

  @override
  Widget build(BuildContext context) {
    if (scheduledTime != null) {
       final now = DateTime.now();
       String text;
       if (scheduledTime!.year == now.year && scheduledTime!.month == now.month && scheduledTime!.day == now.day) {
          text = 'Today';
       } else {
          text = DateFormat('MMM d, yyyy').format(scheduledTime!);
       }
       return Text(
         text,
         style: const TextStyle(
             fontSize: 14,
             fontWeight: FontWeight.w600,
             color: Colors.black87,
         ),
       );
    }

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        return Text(
          DateFormat('MMM d, yyyy').format(DateTime.now()),
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
          ),
        );
      },
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  final DateTime? scheduledTime;

  const _TimeDisplay({this.scheduledTime});

  @override
  Widget build(BuildContext context) {
    if (scheduledTime != null) {
       return Text(
         DateFormat('h:mm a').format(scheduledTime!),
         style: const TextStyle(
             fontSize: 14,
             fontWeight: FontWeight.w600,
             color: Colors.black87,
         ),
       );
    }

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        return Text(
          DateFormat('h:mm a').format(DateTime.now()),
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF9CA3AF),
        letterSpacing: 1.0,
      ),
    );
  }
}