import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/navigation/fade_page_route.dart';
import '../../../../core/services/media_service.dart';
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
  DateTime? _taskDueDate;
  DateTime? _noteDate;
  
  // Media and links state
  final List<String> _taskAttachments = [];
  final List<String> _taskLinks = [];
  final List<String> _noteAttachments = [];
  final List<String> _noteLinks = [];
  final MediaService _mediaService = MediaService();
  bool _isUploadingImage = false;
  
  Future<void> _pickDateTime(bool isTask) async {
    final initialDate = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: initialDate.subtract(const Duration(days: 365)),
      lastDate: initialDate.add(const Duration(days: 365)),
    );
    
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      
      if (pickedTime != null) {
        final dateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        
        setState(() {
          if (isTask) {
            _taskDueDate = dateTime;
          } else {
            _noteDate = dateTime;
          }
        });
      }
    }
  }
  
  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Set Date/Time';
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isTomorrow = dt.year == now.year && dt.month == now.month && dt.day == now.day + 1;
    
    final timeStr = "${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
    
    if (isToday) return 'Today, $timeStr';
    if (isTomorrow) return 'Tomorrow, $timeStr';
    return '${dt.day}/${dt.month}, $timeStr';
  }
  
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
                                label: _formatDateTime(_taskDueDate),
                                isSelected: _taskDueDate != null,
                                onTap: () => _pickDateTime(true),
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
                              // Note Date Chip
                              _buildInteractiveChip(
                                context,
                                icon: Icons.access_time,
                                label: _formatDateTime(_noteDate),
                                isSelected: _noteDate != null,
                                onTap: () => _pickDateTime(false),
                              ),
                              // Add Media button
                              _buildInteractiveChip(
                                context,
                                icon: Icons.attach_file,
                                label: 'Attach',
                                isSelected: _noteAttachments.isNotEmpty,
                                onTap: () => _showAttachmentOptions(false),
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
                    const SizedBox(height: 16),
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
        dueDate: _taskDueDate ?? DateTime.now(),
        priority: _selectedPriority,
        isTask: true,
        tags: [_selectedCategory.name],
        attachments: List.from(_taskAttachments),
        links: List.from(_taskLinks),
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
        createdAt: _noteDate ?? DateTime.now(),
        isTask: false,
        tags: [_selectedCategory.name],
        attachments: List.from(_noteAttachments),
        links: List.from(_noteLinks),
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

  // Show options for attaching media
  void _showAttachmentOptions(bool isTask) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
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
              const SizedBox(height: 20),
              const Text(
                'Add Attachment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildAttachmentOptionCard(
                      context,
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUploadImage(ImageSource.gallery, isTask);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildAttachmentOptionCard(
                      context,
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUploadImage(ImageSource.camera, isTask);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOptionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.12), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pick and upload an image
  Future<void> _pickAndUploadImage(ImageSource source, bool isTask) async {
    setState(() => _isUploadingImage = true);
    
    final url = await _mediaService.pickAndUploadImage(source: source);
    
    setState(() => _isUploadingImage = false);
    
    if (url != null) {
      setState(() {
        if (isTask) {
          _taskAttachments.add(url);
        } else {
          _noteAttachments.add(url);
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload image'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
