import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../notes/domain/models/note.dart';
import '../../../notes/data/notes_provider.dart';
import '../../../agenda/presentation/create_meeting_screen.dart';
import '../../../agenda/presentation/meeting_agenda_screen.dart';
import '../../../agenda/data/meetings_provider.dart';

/// A bottom sheet for creating new tasks or notes.
class CreateNewSheet extends ConsumerStatefulWidget {
  const CreateNewSheet({super.key});

  @override
  ConsumerState<CreateNewSheet> createState() => _CreateNewSheetState();
}

class _CreateNewSheetState extends ConsumerState<CreateNewSheet> {
  NoteCategory _selectedCategory = NoteCategory.work;
  TaskPriority _selectedPriority = TaskPriority.medium;
  bool _isDueTomorrow = false;
  
  final _taskController = TextEditingController();
  final _noteTitleController = TextEditingController();
  final _noteBodyController = TextEditingController();

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
        child: SingleChildScrollView(
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

            // Title
            Text(
              'Create New',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

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
                        label: _isDueTomorrow ? 'Tomorrow' : 'Today',
                        isSelected: _isDueTomorrow,
                        onTap: () => setState(() => _isDueTomorrow = !_isDueTomorrow),
                      ),
                      _buildPriorityChip(context),
                      _buildCategoryChip(context),
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_outlined, color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'NEW NOTE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
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
                  MaterialPageRoute(builder: (_) => const CreateMeetingScreen()),
                );
                if (result != null && context.mounted) {
                  // Navigate to view the created meeting
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MeetingAgendaScreen(data: result)),
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

            // Category Selection
            Row(
              children: [
                Expanded(
                  child: _buildCategoryTile(
                    context,
                    icon: Icons.work_outline,
                    label: 'WORK TASK',
                    value: NoteCategory.work,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCategoryTile(
                    context,
                    icon: Icons.person_outline,
                    label: 'PERSONAL',
                    value: NoteCategory.personal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCategoryTile(
                    context,
                    icon: Icons.lightbulb_outline,
                    label: 'IDEA',
                    value: NoteCategory.idea,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save Button
            Center(
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
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

  Widget _buildCategoryChip(BuildContext context) {
    final categoryLabels = {
      NoteCategory.work: 'Work',
      NoteCategory.personal: 'Personal',
      NoteCategory.idea: 'Idea',
    };
    
    return GestureDetector(
      onTap: () {
        // Cycle through categories
        setState(() {
          final categories = NoteCategory.values;
          final currentIndex = categories.indexOf(_selectedCategory);
          _selectedCategory = categories[(currentIndex + 1) % categories.length];
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
              categoryLabels[_selectedCategory]!,
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

  Widget _buildCategoryTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required NoteCategory value,
  }) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(30) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSave() {
    final taskText = _taskController.text.trim();
    final noteTitle = _noteTitleController.text.trim();
    final noteBody = _noteBodyController.text.trim();
    
    // Determine if we're saving a task or note
    if (taskText.isNotEmpty) {
      // Save as task
      final task = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: taskText,
        category: _selectedCategory,
        createdAt: DateTime.now(),
        dueDate: _isDueTomorrow 
            ? DateTime.now().add(const Duration(days: 1)) 
            : DateTime.now(),
        priority: _selectedPriority,
        isTask: true,
        tags: [_selectedCategory.name],
      );
      ref.read(notesProvider.notifier).addNote(task);
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "$taskText" saved!'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else if (noteTitle.isNotEmpty || noteBody.isNotEmpty) {
      // Save as note
      final note = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: noteTitle.isEmpty ? 'Untitled Note' : noteTitle,
        body: noteBody,
        category: _selectedCategory,
        createdAt: DateTime.now(),
        isTask: false,
        tags: [_selectedCategory.name],
      );
      ref.read(notesProvider.notifier).addNote(note);
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Note saved!'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      // Nothing to save
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a task or note'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

/// Helper function to show the CreateNewSheet
void showCreateNewSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const CreateNewSheet(),
  );
}
