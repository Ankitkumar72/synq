import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/media_service.dart';
import '../domain/models/note.dart';
import '../domain/models/folder.dart';
import '../data/notes_provider.dart';
import '../data/folder_provider.dart';
import '../presentation/widgets/tag_manage_dialog.dart';


class NoteDetailScreen extends ConsumerStatefulWidget {
  final Note? noteToEdit;
  final String? initialFolderId;

  const NoteDetailScreen({super.key, this.noteToEdit, this.initialFolderId});

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  
  late String? _selectedFolderId;
  late DateTime _lastEdited;
  final List<String> _tags = [];
  final List<String> _links = [];
  final List<String> _attachments = [];
  
  bool _isTask = false;
  DateTime? _scheduledTime;
  
  final MediaService _mediaService = MediaService();

  bool _hasUnsavedChanges = false;
  Timer? _debounceTimer;
  bool _isDeleting = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.noteToEdit != null) {
      final note = widget.noteToEdit!;
      _titleController.text = note.title;
      _bodyController.text = note.body ?? '';
      _selectedFolderId = note.folderId;
      _lastEdited = note.updatedAt ?? note.createdAt;
      _tags.addAll(note.tags);
      _links.addAll(note.links);
      _attachments.addAll(note.attachments);
      _isTask = note.isTask;
      _scheduledTime = note.scheduledTime;
    } else {
      _selectedFolderId = widget.initialFolderId;
      _lastEdited = DateTime.now();
      _titleController.text = ''; // Start empty
    }
    
    
    _titleController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuad,
    ));
    
    _animationController.forward();
  }

  void _onTextChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
    
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_hasUnsavedChanges) {
        _handleSave();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    
    if (title.isEmpty && body.isEmpty) return; // Don't save empty
    
    final now = DateTime.now();
    
    final note = (widget.noteToEdit?.copyWith(
          title: title.isEmpty ? 'Untitled' : title,
          body: body,
          folderId: _selectedFolderId,
          tags: _tags,
          links: _links,
          attachments: _attachments,
          updatedAt: now,
          isTask: _isTask,
          scheduledTime: _scheduledTime,
        ) ??
        Note(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title.isEmpty ? 'Untitled' : title,
          body: body,
          category: NoteCategory.work, // Default or derived from folder?
          createdAt: now,
          updatedAt: now,
          folderId: _selectedFolderId,
          tags: _tags,
          links: _links,
          attachments: _attachments,
          isTask: _isTask,
          scheduledTime: _scheduledTime,
        ));

    // Optimistic UI update handled by provider usually, but we verify
    if (widget.noteToEdit == null) {
       await ref.read(notesProvider.notifier).addNote(note);
    } else {
       await ref.read(notesProvider.notifier).updateNote(note);
    }
    
    setState(() {
      _hasUnsavedChanges = false;
      _lastEdited = now;
    });
  }
  
  Future<void> _pickImage() async {
    final path = await _mediaService.pickAndSaveImage(source: ImageSource.gallery);
    if (path != null) {
      setState(() {
        _attachments.add(path);
        _hasUnsavedChanges = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersProvider);
    final notesAsync = ref.watch(notesProvider);

    // Only check for "missing" if we are editing an existing note
    final bool isNoteMissing = widget.noteToEdit != null && 
        notesAsync.hasValue && 
        notesAsync.value?.any((n) => n.id == widget.noteToEdit!.id) == false;

    if (isNoteMissing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
      });
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          title: const Text('Note Removed', style: TextStyle(color: Colors.black, fontSize: 16)),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
              SizedBox(height: 16),
              Text('Note was deleted successfully.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ); 
    }

    final folderName = foldersAsync.when(
      data: (folders) => folders.firstWhere((f) => f.id == _selectedFolderId, orElse: () => Folder(id: '', name: 'Uncategorized', iconCodePoint: 0, colorValue: 0, createdAt: DateTime(2024))).name,
      loading: () => 'Loading...',
      error: (_, __) => 'Error',
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (_hasUnsavedChanges && !_isDeleting) {
          await _handleSave();
        }
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white, // As per design
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
               if (_hasUnsavedChanges && !_isDeleting) await _handleSave();
               if (context.mounted) Navigator.pop(context);
            },
          ),
          title: Text(
            folderName.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
              letterSpacing: 1.2,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Note'),
                    content: const Text('Are you sure you want to delete this note?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          final noteId = widget.noteToEdit?.id;
                          setState(() => _isDeleting = true);
                          
                          // Close dialog and return to home screen
                          if (Navigator.canPop(context)) Navigator.pop(context);
                          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                          
                          if (noteId != null) {
                            ref.read(notesProvider.notifier).deleteNote(noteId).catchError((e) {
                              debugPrint('Error deleting note: $e');
                            });
                          }
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
             Expanded(
               child: FadeTransition(
                 opacity: _fadeAnimation,
                 child: SlideTransition(
                   position: _slideAnimation,
                   child: SingleChildScrollView(
                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Metadata Cards Row
                     SizedBox(
                       height: 90,
                       child: ListView(
                         scrollDirection: Axis.horizontal,
                         children: [
                           _buildMetaCard(
                             icon: Icons.folder_outlined,
                             label: 'PROJECT',
                             value: folderName,
                             color: Colors.blue,
                             onTap: () => _showFolderPicker(context),
                           ),
                           const SizedBox(width: 12),
                           _buildMetaCard(
                             icon: Icons.tag,
                             label: 'TAGS',
                             value: _tags.isNotEmpty ? _tags.first : 'Add Tags',
                             color: Colors.grey[700]!,
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => TagManageDialog(
                                    initialTags: _tags,
                                    onTagsChanged: (tags) {
                                      setState(() {
                                        _tags.clear();
                                        _tags.addAll(tags);
                                        _hasUnsavedChanges = true;
                                      });
                                    },
                                  ),
                                );
                              },
                           ),
                             const SizedBox(width: 12),
                           _buildMetaCard(
                             icon: Icons.link,
                             label: 'RESOURCE',
                             value: _links.isNotEmpty ? '${_links.length} Links' : 'Add Links',
                             color: Colors.blue,
                             onTap: _showLinkManageDialog,
                           ),
                         ],
                       ),
                     ),
                     const SizedBox(height: 24),

                     // Cover Image
                     if (_attachments.isNotEmpty) ...[
                        GestureDetector(
                          onTap: _pickImage,
                          child: Hero(
                            tag: 'note_cover_${widget.noteToEdit?.id ?? "new"}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                _attachments.first,
                                width: double.infinity,
                                height: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: double.infinity,
                                  height: 220,
                                  color: Colors.grey[100],
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 32),
                                        const SizedBox(height: 8),
                                        Text('Image not found', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                     ] else ...[
                        // Placeholder hidden
                     ],

                     // Title
                     TextField(
                       controller: _titleController,
                       decoration: InputDecoration(
                         hintText: 'Title',
                         hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 32, fontWeight: FontWeight.bold),
                         border: InputBorder.none,
                         focusedBorder: InputBorder.none,
                         enabledBorder: InputBorder.none,
                         errorBorder: InputBorder.none,
                         disabledBorder: InputBorder.none,
                         contentPadding: EdgeInsets.zero,
                         filled: false,
                       ),
                       style: GoogleFonts.inter(
                         fontSize: 28,
                         fontWeight: FontWeight.bold,
                         color: Colors.black, // Dark text
                         height: 1.2,
                       ),
                       maxLines: null,
                     ),
                     const SizedBox(height: 8),
                     
                     // Last Edited
                     Text(
                       'Last edited ${_formatLastEdited(_lastEdited)}', 
                       style: GoogleFonts.inter(
                         fontSize: 12,
                         color: Colors.grey[400],
                       ),
                     ),
                     const SizedBox(height: 24),
                     
                     // Body
                     TextField(
                       controller: _bodyController,
                       decoration: InputDecoration(
                          hintText: 'Start writing...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                       ),
                       style: GoogleFonts.inter(
                         fontSize: 16,
                         color: AppColors.textPrimary, 
                         height: 1.6,
                       ),
                       maxLines: null,
                     ),
                     
                     const SizedBox(height: 100), // Spacing for bottom bar
                   ],
                 ),
               ),
              ), // End FadeTransition
            )), // End Expanded
             
             // Bottom Quick Actions Bar
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               decoration: BoxDecoration(
                 color: Colors.grey[50],
                 borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                 boxShadow: [
                     BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0,-2)),
                 ],
               ),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    // Quick Actions Group
                    Row(
                      children: [
                         _buildQuickActionBtn(Icons.auto_awesome, 'Quick\nActions', isLabel: true),
                         const SizedBox(width: 12),
                         _buildQuickActionBtn(
                           _isTask ? Icons.check_box : Icons.check_box_outline_blank, 
                           'Make Task', 
                           isActive: _isTask,
                           onTap: () {
                             setState(() {
                               _isTask = !_isTask;
                               _hasUnsavedChanges = true;
                             });
                             ScaffoldMessenger.of(context).clearSnackBars();
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(
                                 content: Text(
                                   _isTask ? 'Converted to Task' : 'Reverted to Note',
                                   style: const TextStyle(color: Colors.white),
                                 ),
                                 backgroundColor: Colors.black87,
                                 behavior: SnackBarBehavior.floating,
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                 duration: const Duration(seconds: 2),
                               ),
                             );
                           },
                         ), // Make Task
                         const SizedBox(width: 8),
                         _buildQuickActionBtn(
                           Icons.calendar_today, 
                           'Calendar',
                           isActive: _scheduledTime != null,
                           onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _scheduledTime ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  _scheduledTime = pickedDate;
                                  _isTask = true; // Auto-make task if scheduled?
                                  _hasUnsavedChanges = true;
                                });
                              }
                           },
                         ),
                      ],
                    ),
                    
                    // More / Edit FAB equivalent
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black, // Dark FAB
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.image, color: Colors.white, size: 20),
                        onPressed: _pickImage,
                      ),
                    ),
                 ],
               ),
             ),
          ],
        ),
      ),
    );
  }


  Future<void> _showLinkManageDialog() async {
    final textController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Manage Links'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_links.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _links.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final link = _links[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  setDialogState(() {
                                    setState(() {
                                      _links.removeAt(index);
                                      _hasUnsavedChanges = true;
                                    });
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      decoration: InputDecoration(
                        hintText: 'https://example.com',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            if (textController.text.isNotEmpty) {
                              setDialogState(() {
                                setState(() {
                                  _links.add(textController.text.trim());
                                  _hasUnsavedChanges = true;
                                });
                                textController.clear();
                              });
                            }
                          },
                        ),
                      ),
                      onSubmitted: (value) {
                         if (value.isNotEmpty) {
                           setDialogState(() {
                             setState(() {
                               _links.add(value.trim());
                               _hasUnsavedChanges = true;
                             });
                             textController.clear();
                           });
                         }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          }
      ),
    );
  }

  Widget _buildMetaCard({required IconData icon, required String label, required String value, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140, // Fixed width card
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Icon(icon, size: 16, color: color),
                 if (label == 'RESOURCE')
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
              ],
            ),
             const Spacer(),
             Text(
               label,
               style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[400]),
             ),
             const SizedBox(height: 4),
             Text(
               value,
               maxLines: 1,
               overflow: TextOverflow.ellipsis,
               style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
             ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickActionBtn(IconData icon, String label, {bool isLabel = false, bool isActive = false, VoidCallback? onTap}) {
    if (isLabel) {
       return Row(
         children: [
           Icon(icon, color: Colors.blue, size: 20),
           const SizedBox(width: 8),
           Text(
             label,
             style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600], height: 1.1),
           )
         ],
       );
    }
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isActive ? Colors.white : Colors.black87),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: isActive ? Colors.white : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastEdited(DateTime dt) {
    if (DateTime.now().difference(dt).inMinutes < 1) return 'just now';
    if (DateTime.now().difference(dt).inMinutes < 60) return '${DateTime.now().difference(dt).inMinutes}m ago';
    if (DateTime.now().difference(dt).inHours < 24) return '${DateTime.now().difference(dt).inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
  
  Future<void> _showFolderPicker(BuildContext context) async {
    final foldersAsync = ref.read(foldersProvider);
    foldersAsync.whenData((folders) async {
      final pickedId = await showModalBottomSheet<String>(
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
                     Text('Select Project/Folder', style: Theme.of(context).textTheme.titleLarge),
                     const SizedBox(height: 10),
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
       if (pickedId != null) {
          setState(() {
             _selectedFolderId = pickedId;
             _hasUnsavedChanges = true;
          });
       }
    });
  }
}
