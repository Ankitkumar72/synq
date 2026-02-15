import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/media_service.dart';
import '../../../../core/navigation/fade_page_route.dart';
import '../domain/models/note.dart';
import '../domain/models/folder.dart';
import '../data/notes_provider.dart';
import '../data/folder_provider.dart';
import '../data/note_editor_draft_store.dart';
import 'folders_screen.dart';
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
  Note? _editingNote;
  final List<String> _tags = [];
  final List<String> _links = [];
  final List<String> _attachments = [];
  
  bool _isTask = false;
  DateTime? _scheduledTime;
  
  final MediaService _mediaService = MediaService();

  late final String _draftKey;
  String? _draftNoteId;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _draftKey = widget.noteToEdit != null
        ? 'edit:${widget.noteToEdit!.id}'
        : 'new:${widget.initialFolderId ?? 'none'}';
    _draftNoteId = widget.noteToEdit?.id;

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
      _editingNote = note;
    } else {
      _selectedFolderId = widget.initialFolderId;
      _lastEdited = DateTime.now();
      _titleController.text = ''; // Start empty
      _editingNote = null;
    }

    _restoreDraftIfAvailable();
    
    
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

  void _restoreDraftIfAvailable() {
    final draft = NoteEditorDraftStore.read(_draftKey);
    if (draft == null) return;

    _draftNoteId = draft.noteId ?? _draftNoteId;
    _titleController.text = draft.title;
    _bodyController.text = draft.body;
    _selectedFolderId = draft.selectedFolderId;
    _tags
      ..clear()
      ..addAll(draft.tags);
    _links
      ..clear()
      ..addAll(draft.links);
    _attachments
      ..clear()
      ..addAll(draft.attachments);
    _isTask = draft.isTask;
    _scheduledTime = draft.scheduledTime;
    _lastEdited = draft.lastEdited;
    _hasUnsavedChanges = true;
  }

  void _persistDraft() {
    NoteEditorDraftStore.write(
      _draftKey,
      NoteEditorDraft(
        noteId: _draftNoteId,
        title: _titleController.text,
        body: _bodyController.text,
        selectedFolderId: _selectedFolderId,
        tags: List<String>.from(_tags),
        links: List<String>.from(_links),
        attachments: List<String>.from(_attachments),
        isTask: _isTask,
        scheduledTime: _scheduledTime,
        lastEdited: DateTime.now(),
      ),
    );
  }

  void _markUnsaved({bool notify = true}) {
    if (!_hasUnsavedChanges) {
      if (notify && mounted) {
        setState(() => _hasUnsavedChanges = true);
      } else {
        _hasUnsavedChanges = true;
      }
    }
    _persistDraft();
  }

  void _onTextChanged() {
    _markUnsaved();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    
    if (title.isEmpty && body.isEmpty) return; // Don't save empty
    
    final now = DateTime.now();
    final noteId = _editingNote?.id ?? _draftNoteId ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    final note = (_editingNote?.copyWith(
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
          id: noteId,
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

    setState(() => _isSaving = true);

    try {
      if (_editingNote == null) {
        await ref.read(notesProvider.notifier).addNote(note);
      } else {
        await ref.read(notesProvider.notifier).updateNote(note);
      }

      if (!mounted) return;

      setState(() {
        _hasUnsavedChanges = false;
        _lastEdited = now;
        _editingNote = note;
        _draftNoteId = note.id;
      });
      NoteEditorDraftStore.remove(_draftKey);
    } catch (_) {
      _persistDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save right now. Draft kept locally.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      } else {
        _isSaving = false;
      }
    }
  }
  
  Future<void> _pickImage() async {
    final path = await _mediaService.pickAndSaveImage(source: ImageSource.gallery);
    if (path != null) {
      setState(() {
        _attachments.add(path);
        _hasUnsavedChanges = true;
      });
      _persistDraft();
    }
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersProvider);
    final notesAsync = ref.watch(notesProvider);

    // Only check for "missing" if we are editing an existing note
    final bool isNoteMissing = _editingNote != null && 
        notesAsync.hasValue && 
        notesAsync.value?.any((n) => n.id == _editingNote!.id) == false;

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
          title: Text('Note Removed', style: GoogleFonts.inter(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
              ),
              const SizedBox(height: 24),
              Text(
                'Note was deleted successfully.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Back to Home', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
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
    final isUncategorized = folderName.trim().toLowerCase() == 'uncategorized';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (_hasUnsavedChanges) {
          _persistDraft();
        }
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white, // As per design
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 84,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
               if (_hasUnsavedChanges) _persistDraft();
               if (context.mounted) Navigator.pop(context);
            },
          ),
          title: Text(
            folderName,
            textAlign: TextAlign.center,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: isUncategorized ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: isUncategorized ? Colors.black54 : Colors.black,
            ),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _handleSave,
              child: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        body: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: 1.0,
          child: Column(
            children: [
               Expanded(
               child: FadeTransition(
                 opacity: _fadeAnimation,
                 child: SlideTransition(
                   position: _slideAnimation,
                   child: SingleChildScrollView(
                 padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                             onTap: () {
                               Navigator.push(
                                 context,
                                 FadePageRoute(builder: (_) => const FoldersScreen()),
                               );
                             },
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
                                      _persistDraft();
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
                        const SizedBox(height: 24),
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
                     
                     
                   ],
                 ),
               ),
               ),
               ),
              ), // End FadeTransition
              
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

                           _buildQuickActionBtn(
                             _isTask ? Icons.check_box : Icons.check_box_outline_blank, 
                             'Make Task', 
                             isActive: _isTask,
                             onTap: () {
                                setState(() {
                                  _isTask = !_isTask;
                                  _hasUnsavedChanges = true;
                                });
                                _persistDraft();
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
                                   _persistDraft();
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
                                    _persistDraft();
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
                                _persistDraft();
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
                             _persistDraft();
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
}
