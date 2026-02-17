import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';

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
  String _saveStatus = 'Saved';
  Timer? _autoSaveTimer;
  
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
    
    // Auto-save logic
    setState(() {
      _saveStatus = 'Saving...';
    });
    
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _handleSave();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _autoSaveTimer?.cancel();
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
        _saveStatus = 'Saved';
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
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                folderName.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Text(
                _saveStatus.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF5473F7),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: Colors.black),
              onSelected: (value) {
                switch (value) {
                  case 'move':
                    Navigator.push(
                      context,
                      FadePageRoute(builder: (_) => const FoldersScreen()),
                    );
                    break;
                  case 'save':
                    _handleSave();
                    break;
                  case 'tags':
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
                    break;
                  case 'image':
                    _pickImage();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'move',
                  child: Text('Move to Project'),
                ),
                const PopupMenuItem(
                  value: 'save',
                  child: Text('Save Now'),
                ),
                const PopupMenuItem(
                  value: 'tags',
                  child: Text('Edit Tags'),
                ),
                const PopupMenuItem(
                  value: 'image',
                  child: Text('Add Image'),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: 1.0,
              child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle: GoogleFonts.merriweather(
                          color: Colors.grey.shade400,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                      ),
                      style: GoogleFonts.merriweather(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.2,
                      ),
                      maxLines: null,
                    ),
                    const SizedBox(height: 24),

                    // Body
                    TextField(
                      controller: _bodyController,
                      decoration: InputDecoration(
                        hintText: 'Start writing...',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
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
                        height: 1.5,
                      ),
                      maxLines: null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
            // Floating Formatting Toolbar (Pill Shape)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).viewInsets.bottom,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _buildToolbarButton(Icons.format_bold, () => _formatText('**', '**')),
                                _buildToolbarButton(Icons.format_italic, () => _formatText('*', '*')),
                                _buildToolbarButton(Icons.format_underlined, () => _formatText('<u>', '</u>')),
                                const SizedBox(width: 8),
                                Container(width: 1, height: 24, color: Colors.grey[200]),
                                const SizedBox(width: 8),
                                _buildToolbarButton(Icons.text_fields, () => _formatText('# ', '')),
                                _buildToolbarButton(Icons.format_list_bulleted, () => _formatText('- ', '')),
                                _buildToolbarButton(Icons.format_quote, () => _formatText('> ', '')),
                              ],
                            ),
                            _buildToolbarButton(Icons.keyboard_hide, () {
                              FocusScope.of(context).unfocus();
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 20, color: Colors.grey[700]),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }

  void _formatText(String prefix, String suffix) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    
    if (selection.isCollapsed) {
      // Insert at cursor
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$suffix');
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length),
      );
    } else {
      // Wrap selected text
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start,
          extentOffset: selection.end + prefix.length + suffix.length,
        ),
      );
    }
  }



  String _formatLastEdited(DateTime dt) {
    if (DateTime.now().difference(dt).inMinutes < 1) return 'just now';
    if (DateTime.now().difference(dt).inMinutes < 60) return '${DateTime.now().difference(dt).inMinutes}m ago';
    if (DateTime.now().difference(dt).inHours < 24) return '${DateTime.now().difference(dt).inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}
