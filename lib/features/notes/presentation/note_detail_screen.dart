import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:synq/features/notes/utils/markdown_bridge.dart';
import 'package:synq/features/notes/utils/html_parser.dart';
import 'package:synq/core/theme/app_theme.dart';
import 'dart:io';
import 'package:synq/core/services/media_service.dart';
import 'package:synq/features/notes/domain/models/note.dart';
import 'package:synq/features/folders/domain/models/folder.dart';
import 'package:synq/features/notes/data/notes_provider.dart';
import 'package:synq/features/attachments/data/image_storage_service.dart';
import 'package:synq/features/folders/data/folder_provider.dart';
import 'package:synq/features/notes/data/note_editor_draft_store.dart';
import 'package:synq/features/notes/presentation/widgets/tag_manage_dialog.dart';
import 'package:synq/core/navigation/fade_page_route.dart';
import 'package:synq/core/utils/icon_utils.dart';
import 'package:synq/features/folders/presentation/folders_screen.dart';
import 'package:synq/features/notes/presentation/widgets/note_options_sheet.dart';
import 'package:synq/core/services/device_service.dart';
import 'package:synq/features/auth/presentation/providers/user_provider.dart';
import 'package:synq/features/auth/domain/models/synq_user.dart';
import 'package:synq/core/providers/repository_provider.dart';
import 'package:synq/features/notes/presentation/widgets/inline_image_embed.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:synq/core/widgets/synq_ui_toolkit.dart';

class _HandleCustomPasteShortcut extends Intent {
  const _HandleCustomPasteShortcut();
}

class NoteDetailScreen extends ConsumerStatefulWidget {
  final Note? noteToEdit;
  final String? initialFolderId;

  const NoteDetailScreen({super.key, this.noteToEdit, this.initialFolderId});

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  late final quill.QuillController _quillController;

  final _titleFocusNode = FocusNode();
  final _bodyFocusNode = FocusNode();

  late String? _selectedFolderId;
  Note? _editingNote;
  final List<String> _tags = [];
  final List<String> _links = [];
  final List<String> _attachments = [];

  bool _isTask = false;
  bool _isReadOnly = false;
  DateTime? _scheduledTime;

  final MediaService _mediaService = MediaService();
  final DeviceService _deviceService = DeviceService();

  late final String _draftKey;
  String? _draftNoteId;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  late final ValueNotifier<String> _saveStatusNotifier;
  Timer? _autoSaveTimer;
  StreamSubscription<Note?>? _noteSubscription;
  StreamSubscription<quill.DocChange>? _quillSubscription;
  String? _deviceId;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _saveStatusNotifier = ValueNotifier('Saved');
    _draftKey = widget.noteToEdit != null
        ? 'edit:${widget.noteToEdit!.id}'
        : 'new:${widget.initialFolderId ?? 'none'}';
    _draftNoteId = widget.noteToEdit?.id;

    if (widget.noteToEdit != null) {
      final note = widget.noteToEdit!;
      _titleController.text = note.title;
      _quillController = quill.QuillController(
        document: MarkdownBridge.deltaFromMarkdown(note.body),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: _isReadOnly,
      );
      _selectedFolderId = note.folderId;
      _tags.addAll(note.tags);
      _links.addAll(note.links);
      _attachments.addAll(note.attachments);
      _isTask = note.isTask;
      _scheduledTime = note.scheduledTime;
      _editingNote = note;
    } else {
      _selectedFolderId = widget.initialFolderId;
      _titleController.text = ''; // Start empty
      _quillController = quill.QuillController(
        document: quill.Document(),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: _isReadOnly,
      );
      _editingNote = null;
    }

    _restoreDraftIfAvailable();

    _titleController.addListener(_onTextChanged);

    // Listen to focus changes to toggle toolbar
    _bodyFocusNode.addListener(() {
      setState(() {});
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutQuad,
          ),
        );

    _animationController.forward();
    _loadDeviceId();
    _setupNoteSubscription();
    _setupQuillChangeTracking();
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _titleController.dispose();
    _quillController.dispose();
    _animationController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _autoSaveTimer?.cancel();
    _noteSubscription?.cancel();
    _quillSubscription?.cancel();
    _saveStatusNotifier.dispose();
    super.dispose();
  }

  void _setupQuillChangeTracking() {
    _quillSubscription = _quillController.document.changes.listen((change) {
      // 1. Analyze for slash command (/image )
      final delta = change.change;
      final text = _quillController.document.toPlainText();
      final selection = _quillController.selection;
      
      // If the change was an insertion and ends with a space
      if (selection.isCollapsed && selection.start >= 7) {
        final checkRange = text.substring(selection.start - 7, selection.start);
        if (checkRange == '/image ') {
          // Remove the command text
          _quillController.replaceText(selection.start - 7, 7, '', null);
          // Auto-trigger image menu
          _showImageSourceMenu();
        }
      }

      // 2. Analyze for attachment sync
      bool hasImageChange = false;
      for (final op in delta.toList()) {
        if (op.isInsert && op.data is Map && (op.data as Map).containsKey('image')) {
          hasImageChange = true;
          break;
        }
        if (op.isDelete) {
          hasImageChange = true;
          break;
        }
      }

      if (hasImageChange) {
        _syncAttachmentsFromDelta();
      }

      // Trigger auto-save
      _onTextChanged();
    });
  }

  Future<void> _loadDeviceId() async {
    final info = await _deviceService.getDeviceInfo();
    if (mounted) {
      setState(() => _deviceId = info['id']);
    }
  }

  void _setupNoteSubscription() {
    if (widget.noteToEdit == null) return;

    _noteSubscription = ref
        .read(notesRepositoryProvider)
        .watchNote(widget.noteToEdit!.id)
        .listen((note) {
          if (note == null || !mounted) return;

          // Merge logic: only update if the remote note is newer and edited by a different device
          if (_editingNote != null &&
              note.updatedAt != null &&
              (_editingNote!.updatedAt == null ||
                  note.updatedAt!.isAfter(_editingNote!.updatedAt!)) &&
              note.deviceLastEdited != _deviceId) {
            setState(() {
              _editingNote = note;
              _titleController.text = note.title;
              _quillController.document = MarkdownBridge.deltaFromMarkdown(
                note.body,
              );
              _selectedFolderId = note.folderId;
              _tags.clear();
              _tags.addAll(note.tags);
              _attachments.clear();
              _attachments.addAll(note.attachments);
              _saveStatusNotifier.value = 'Synced';
            });
          }
        });
  }

  void _restoreDraftIfAvailable() {
    final draft = NoteEditorDraftStore.read(_draftKey);
    if (draft == null) return;

    // When editing an existing note, only restore the draft if it is
    // strictly newer than the server copy. This prevents a stale
    // crash-draft from silently overwriting a note that was already
    // updated (e.g. from another device) after the draft was created.
    if (widget.noteToEdit != null) {
      final serverUpdatedAt = widget.noteToEdit!.updatedAt;
      if (serverUpdatedAt != null &&
          !draft.lastEdited.isAfter(serverUpdatedAt)) {
        // Draft is the same age or older — discard it.
        NoteEditorDraftStore.remove(_draftKey);
        return;
      }
    }

    _draftNoteId = draft.noteId ?? _draftNoteId;
    _titleController.text = draft.title;

    _quillController.document = MarkdownBridge.deltaFromMarkdown(draft.body);

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
    _hasUnsavedChanges = true;
  }

  void _persistDraft() {
    NoteEditorDraftStore.write(
      _draftKey,
      NoteEditorDraft(
        noteId: _draftNoteId,
        title: _titleController.text,
        body: MarkdownBridge.markdownFromDelta(_quillController.document),
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
    _saveStatusNotifier.value = 'Saving...';

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () async {
      if (!_isSaving) {
        await _handleSave();
      } else {
        // Already saving — reschedule with a proper async closure so we
        // await the next save and don't silently drop it.
        _autoSaveTimer?.cancel();
        _autoSaveTimer = Timer(
          const Duration(seconds: 1),
          () async => await _handleSave(),
        );
      }
    });
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    final body = MarkdownBridge.markdownFromDelta(
      _quillController.document,
    ).trim();

    final isCurrentlyEmpty = title.isEmpty && body.isEmpty;
    final wasEmpty = _editingNote == null && _draftNoteId == null;

    if (isCurrentlyEmpty) {
      if (!wasEmpty && _editingNote != null) {
        // If it was non-empty and now empty, maybe prompt or just return
        // For now, let's just return to avoid saving empty notes
        _saveStatusNotifier.value = 'Empty';
      }
      return;
    }

    final now = DateTime.now();
    final noteId =
        _editingNote?.id ??
        _draftNoteId ??
        const Uuid().v4();

    final note =
        (_editingNote?.copyWith(
          title: title.isEmpty ? 'Untitled' : title,
          body: body,
          folderId: _selectedFolderId,
          tags: _tags,
          links: _links,
          attachments: _attachments,
          updatedAt: now,
          deviceLastEdited: _deviceId,
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
          deviceLastEdited: _deviceId,
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
        _editingNote = note;
        _draftNoteId = note.id;
        _saveStatusNotifier.value = 'Saved';
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
    final user = ref.read(userProvider).valueOrNull;
    if (user == null) return;

    if (_attachments.length >= ImageStorageService.maxAttachmentsPerNote) {
      _showToast(
        context,
        'Max ${ImageStorageService.maxAttachmentsPerNote} images reached.',
      );
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    _handleSingleImagePath(image.path);
  }

  Future<void> _pickImages() async {
    final user = ref.read(userProvider).valueOrNull;
    if (user == null) return;

    if (_attachments.length >= ImageStorageService.maxAttachmentsPerNote) {
      _showToast(context, 'Max images reached.');
      return;
    }

    final List<File> images = await _mediaService.pickMultiImage();
    if (images.isEmpty) return;

    for (final img in images) {
      await _handleSingleImagePath(img.path);
    }
  }

  Future<void> _handleSingleImagePath(String path) async {
    final user = ref.read(userProvider).valueOrNull;
    if (user == null) return;

    final noteId = _editingNote?.id ??
        _draftNoteId ??
        'temp_${const Uuid().v4()}';

    _saveStatusNotifier.value = 'Optimizing...';

    try {
      final storageResult = await ImageStorageService.storeImage(
        sourceFile: File(path),
        planTier: user.planTier,
      );

      String finalUri;

      if (user.planTier.isPro && storageResult.hasServerCopy) {
        _saveStatusNotifier.value = 'Uploading...';
        finalUri = await ImageStorageService.uploadFileToCloud(
          file: File(storageResult.serverCopyPath!),
          userId: user.id,
          noteId: noteId,
          onProgress: (progress) {
            if (mounted) {
              final percentage = (progress * 100).toInt();
              _saveStatusNotifier.value = 'Uploading $percentage%';
            }
          },
        );
      } else {
        finalUri = storageResult.localOriginalPath;
      }

      final selection = _quillController.selection;
      final index = selection.isValid ? selection.end : _quillController.document.length;
      
      _quillController.document.insert(
        index,
        quill.BlockEmbed.image(finalUri),
      );
      
      // Default width attribute
      _quillController.formatText(
        index,
        1,
        quill.Attribute('width', quill.AttributeScope.inline, 300),
      );
      
      // Move cursor after the image
      _quillController.updateSelection(
        TextSelection.collapsed(offset: index + 1),
        quill.ChangeSource.local,
      );

      setState(() {
        _attachments.add(finalUri);
        _hasUnsavedChanges = true;
        _saveStatusNotifier.value = 'Saved';
      });
      _handleSave();
    } catch (e) {
      debugPrint('Error handling image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add image: $e')),
        );
        _saveStatusNotifier.value = 'Error';
      }
    }
  }

  void _syncAttachmentsFromDelta() {
    final delta = _quillController.document.toDelta();
    final List<String> currentImageUris = [];
    
    for (final op in delta.toList()) {
      if (op.isInsert && op.data is Map) {
        final data = op.data as Map;
        if (data.containsKey('image')) {
          currentImageUris.add(data['image'] as String);
        }
      }
    }

    if (!setEquals(_attachments.toSet(), currentImageUris.toSet())) {
      setState(() {
        _attachments.clear();
        _attachments.addAll(currentImageUris);
        _hasUnsavedChanges = true;
      });
      _persistDraft();
    }
  }

  void _showImageSourceMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Insert Image',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF5473F7)),
              title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF5473F7)),
              title: const Text('Photo Library', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: Color(0xFF5473F7)),
              title: const Text('Image URL', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _showImageUrlDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    final file = await _mediaService.pickImage(source: source);
    if (file != null) {
      await _handleSingleImagePath(file.path);
    }
  }

  void _showImageUrlDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert Image URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com/image.png',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _insertRemoteImage(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  void _insertRemoteImage(String url) {
    if (url.isEmpty) return;
    final selection = _quillController.selection;
    _quillController.document.insert(
      selection.end,
      quill.BlockEmbed.image(url),
    );
    _quillController.updateSelection(
      TextSelection.collapsed(offset: selection.end + 1),
      quill.ChangeSource.local,
    );
    _markUnsaved();
  }

  Future<void> _openFolderPicker() async {
    final foldersState = ref.read(foldersProvider);
    final folders = foldersState.value ?? const <Folder>[];

    const uncategorizedValue = '__uncategorized__';
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Move To Folder',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.folder_off_outlined,
                            color: Colors.grey,
                          ),
                          title: const Text(
                            'Uncategorized',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: _selectedFolderId == null
                              ? const Icon(
                                  Icons.check,
                                  color: Color(0xFF5473F7),
                                )
                              : null,
                          onTap: () =>
                              Navigator.pop(context, uncategorizedValue),
                        ),
                        const Divider(height: 1),
                        ...folders.map((folder) {
                          final isSelected = _selectedFolderId == folder.id;
                          return ListTile(
                            leading: Icon(
                              IconUtils.getIconFromCodePoint(
                                folder.iconCodePoint,
                              ),
                              color: Color(
                                folder.colorValue,
                              ).withValues(alpha: 1.0),
                            ),
                            title: Text(
                              folder.name,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Color(0xFF5473F7),
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, folder.id),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    final nextFolderId = selected == uncategorizedValue ? null : selected;
    if (nextFolderId == _selectedFolderId) return;

    setState(() {
      _selectedFolderId = nextFolderId;
      _hasUnsavedChanges = true;
    });
    _persistDraft();
    _handleSave();

    if (mounted) {
      final folderName = nextFolderId == null
          ? 'Uncategorized'
          : folders.any((f) => f.id == nextFolderId)
          ? folders.firstWhere((f) => f.id == nextFolderId).name
          : 'Folder';

      final fileName = _titleController.text.trim().isEmpty
          ? 'Untitled'
          : _titleController.text.trim();
      _showToast(context, '$fileName Moved to $folderName.');
    }
  }

  void _showToast(BuildContext context, String message) {
    debugPrint('SHOWING TOAST (EDITOR): $message');
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 120,
        left: 40,
        right: 40,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color(0xFF5473F7).withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _showNoteOptions(BuildContext context) {
    final currentNote = _editingNote ??
        Note(
          id: _draftNoteId ?? const Uuid().v4(),
          title: _titleController.text.trim().isEmpty
              ? 'Untitled'
              : _titleController.text.trim(),
          body: MarkdownBridge.markdownFromDelta(_quillController.document).trim(),
          category: NoteCategory.work,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          folderId: _selectedFolderId,
          tags: _tags,
          links: _links,
          attachments: _attachments,
          isTask: _isTask,
          scheduledTime: _scheduledTime,
        );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return NoteOptionsSheet(
          note: currentNote,
          isReadOnly: _isReadOnly,
          onClose: () {
            Navigator.pop(sheetContext); // Close sheet
            Navigator.of(context).pop(); // Close note editor
          },
          onToggleReadingView: () {
            setState(() {
              _isReadOnly = !_isReadOnly;
              _quillController.readOnly = _isReadOnly;
            });
            // Reliably dismiss the keyboard when entering read-only mode
            if (_isReadOnly) {
              _titleFocusNode.unfocus();
              _bodyFocusNode.unfocus();
              // Delayed fallback for platforms that don't dismiss immediately
              Future.delayed(const Duration(milliseconds: 100), () {
                FocusManager.instance.primaryFocus?.unfocus();
              });
            }
          },
          onRename: () {
            Navigator.pop(sheetContext);
            _showRenameDialog();
          },
          onMove: () {
            _openFolderPicker();
          },
          onDelete: () {
            _confirmDelete();
          },
          onFind: () {
            Navigator.pop(sheetContext);
            _showFindReplaceDialog(isReplace: false);
          },
          onReplace: () {
            Navigator.pop(sheetContext);
            _showFindReplaceDialog(isReplace: true);
          },
        );
      },
    );
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      _hasUnsavedChanges = false;
      NoteEditorDraftStore.remove(_draftKey);
      if (_editingNote != null) {
        await ref.read(notesProvider.notifier).deleteNote(_editingNote!.id);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _titleController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename Note', style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'New title...',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _titleController.text = controller.text.trim());
                _markUnsaved();
                _handleSave();
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5473F7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showFindReplaceDialog({required bool isReplace}) {
    final findController = TextEditingController();
    final replaceController = TextEditingController();
    int matchCount = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(isReplace ? 'Find & Replace' : 'Find', style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: findController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Search for...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    final text = _quillController.document.toPlainText();
                    final count = val.isEmpty ? 0 : val.allMatches(text).length;
                    setDialogState(() => matchCount = count);
                  },
                ),
                if (matchCount > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5473F7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$matchCount occurrences found.',
                      style: const TextStyle(color: Color(0xFF5473F7), fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isReplace) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: replaceController,
                      decoration: InputDecoration(
                        labelText: 'Replace with...',
                        prefixIcon: const Icon(Icons.find_replace),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
              ),
              if (matchCount > 0 && isReplace)
                ElevatedButton(
                  onPressed: () {
                    _performReplace(findController.text, replaceController.text);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5473F7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Replace All'),
                ),
            ],
          );
        },
      ),
    );
  }

  void _performReplace(String find, String replace) {
    if (find.isEmpty) return;

    final plainText = _quillController.document.toPlainText();
    final matches = find.allMatches(plainText).toList();
    if (matches.isEmpty) return;

    // Apply replacements from end → start so earlier offsets stay valid
    // without shifting, while preserving rich text formatting.
    for (final match in matches.reversed) {
      _quillController.replaceText(match.start, find.length, replace, null);
    }

    _showToast(context, 'Replaced ${matches.length} occurrence${matches.length == 1 ? '' : 's'}');
    _markUnsaved();
    _handleSave();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    final foldersAsync = ref.watch(foldersProvider);

    final bool isNoteMissing =
        _editingNote != null &&
        notesAsync.hasValue &&
        notesAsync.value?.any((n) => n.id == _editingNote!.id) == false;

    if (isNoteMissing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          title: Text(
            'Note Removed',
            style: GoogleFonts.roboto(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
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
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Note was deleted successfully.',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Back to Home',
                    style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final folderName = foldersAsync.when(
      data: (folders) => folders
          .firstWhere(
            (f) => f.id == _selectedFolderId,
            orElse: () => Folder(
              id: '',
              name: 'Uncategorized',
              iconCodePoint: 0,
              colorValue: 0,
              createdAt: DateTime(2024),
            ),
          )
          .name,
      loading: () => 'Loading...',
      error: (_, __) => 'Error',
    );

    const toolbarHeight = 48.0;
    const toolbarGap = 6.0;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardVisible = keyboardInset > 0;
    final showKeyboardToolbar = isKeyboardVisible && _bodyFocusNode.hasFocus;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (_hasUnsavedChanges) {
          _persistDraft();
          await _handleSave();
        }
        if (context.mounted) Navigator.of(context).pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark 
              ? Brightness.light 
              : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Theme.of(context).brightness == Brightness.dark 
              ? Brightness.light 
              : Brightness.dark,
        ),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 84,
            leading: IconButton(
              icon: const Icon(Icons.folder_open_outlined, color: Colors.black),
              tooltip: 'Folders',
              onPressed: () {
                Navigator.of(context).push(
                  FadePageRoute(builder: (context) => const FoldersScreen()),
                );
              },
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  folderName.toUpperCase(),
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 1.0,
                  ),
                ),
                ValueListenableBuilder<String>(
                  valueListenable: _saveStatusNotifier,
                  builder: (context, status, _) {
                    return Text(
                      status.toUpperCase(),
                      style: GoogleFonts.roboto(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5473F7),
                        letterSpacing: 1.5,
                      ),
                    );
                  },
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.black),
                onPressed: () => _showNoteOptions(context),
              ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: 1.0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        0,
                        24,
                        showKeyboardToolbar
                            ? (toolbarHeight + toolbarGap + 28)
                            : (24 + MediaQuery.paddingOf(context).bottom),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 30),
                            child: TextField(
                              controller: _titleController,
                              focusNode: _titleFocusNode,
                              readOnly: _isReadOnly,
                              textAlign: TextAlign.left,
                              decoration: InputDecoration(
                                hintText: 'Title',
                                hintStyle: GoogleFonts.roboto(
                                  color: Colors.grey.shade400,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                ),
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                filled: false,
                              ),
                              style: GoogleFonts.roboto(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                height: 1.2,
                              ),
                              maxLines: null,
                            ),
                          ),
Container(
                            constraints: BoxConstraints(
                              minHeight: MediaQuery.of(context).size.height * 0.5,
                            ),
                            child: DropRegion(
                              formats: const [Formats.png, Formats.jpeg],
                              onDropOver: (event) => DropOperation.copy,
                              onPerformDrop: (event) async {
                                final item = event.session.items.first;
                                final reader = item.dataReader;
                                if (reader == null) return;

                                if (reader.canProvide(Formats.png) || reader.canProvide(Formats.jpeg)) {
                                  final format = reader.canProvide(Formats.png) ? Formats.png : Formats.jpeg;
                                  final extension = format == Formats.png ? 'png' : 'jpg';

                                  final completer = Completer<Uint8List?>();
                                  reader.getFile(format, (file) async {
                                    final bytes = await file.readAll();
                                    completer.complete(bytes);
                                  }, onError: (e) => completer.complete(null));

                                  final bytes = await completer.future;
                                  if (bytes != null) {
                                    final path = await _mediaService.saveBytesToLocalDocuments(bytes, extension: extension);
                                    if (path != null) {
                                      _handleSingleImagePath(path);
                                    }
                                  }
                                }
                              },
                              child: RepaintBoundary(
                                  child: quill.QuillEditor.basic(
                                    controller: _quillController,
                                    focusNode: _bodyFocusNode,
                                    config: quill.QuillEditorConfig(
                                      placeholder: 'Start writing...',
                                      embedBuilders: [InlineImageEmbedBuilder()],
                                      customShortcuts: {
                                      LogicalKeySet(
                                        LogicalKeyboardKey.meta,
                                        LogicalKeyboardKey.keyV,
                                      ): const _HandleCustomPasteShortcut(),
                                      LogicalKeySet(
                                        LogicalKeyboardKey.control,
                                        LogicalKeyboardKey.keyV,
                                      ): const _HandleCustomPasteShortcut(),
                                    },
                                    customActions: {
                                      _HandleCustomPasteShortcut:
                                          CallbackAction<_HandleCustomPasteShortcut>(
                                            onInvoke: (intent) => _handleCustomPaste().then((_) => null),
                                          ),
                                    },
                                    scrollable: false,
                                    padding: EdgeInsets.zero,
                                    autoFocus: false,
                                    expands: false,
                                    customStyles: quill.DefaultStyles(
                                      paragraph: quill.DefaultTextBlockStyle(
                                        GoogleFonts.roboto(
                                          fontSize: 18,
                                          height: 1.6,
                                          color: Colors.black87,
                                        ),
                                        const quill.HorizontalSpacing(0, 0),
                                        const quill.VerticalSpacing(0, 0),
                                        const quill.VerticalSpacing(0, 0),
                                        null,
                                      ),
                                    h1: quill.DefaultTextBlockStyle(
                                      GoogleFonts.roboto(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                        height: 1.15,
                                      ),
                                      const quill.HorizontalSpacing(0, 0),
                                      const quill.VerticalSpacing(16, 8),
                                      const quill.VerticalSpacing(0, 0),
                                      null,
                                    ),
                                    h2: quill.DefaultTextBlockStyle(
                                      GoogleFonts.roboto(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                        height: 1.15,
                                      ),
                                      const quill.HorizontalSpacing(0, 0),
                                      const quill.VerticalSpacing(14, 6),
                                      const quill.VerticalSpacing(0, 0),
                                      null,
                                    ),
                                    code: quill.DefaultTextBlockStyle(
                                      GoogleFonts.robotoMono(
                                        fontSize: 15,
                                        color: Colors.blue.shade900,
                                      ),
                                      const quill.HorizontalSpacing(12, 12),
                                      const quill.VerticalSpacing(12, 12),
                                      const quill.VerticalSpacing(0, 0),
                                      BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                    ),
                                    placeHolder: quill.DefaultTextBlockStyle(
                                      GoogleFonts.roboto(
                                        fontSize: 17,
                                        color: Colors.grey.shade400,
                                        height: 1.6,
                                      ),
                                      const quill.HorizontalSpacing(0, 0),
                                      const quill.VerticalSpacing(0, 0),
                                      const quill.VerticalSpacing(0, 0),
                                      null,
                                    ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: 12,
                right: 12,
                bottom: showKeyboardToolbar ? 12 : -120,
                child: Container(
                  height: toolbarHeight,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(44),
                      side: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListenableBuilder(
                    listenable: _quillController,
                    builder: (context, _) {
                      final selectionStyle = _quillController.getSelectionStyle();
                      final isBold = selectionStyle.attributes.containsKey(quill.Attribute.bold.key);
                      final isItalic = selectionStyle.attributes.containsKey(quill.Attribute.italic.key);
                      final isUnderline = selectionStyle.attributes.containsKey(quill.Attribute.underline.key);
                      final listAttr = selectionStyle.attributes[quill.Attribute.list.key];
                      final isBullet = listAttr?.value == 'bullet';
                      final isOrdered = listAttr?.value == 'ordered';
                      final isChecklist = listAttr?.value == 'checked' || listAttr?.value == 'unchecked';
                      final headerAttr = selectionStyle.attributes[quill.Attribute.header.key];
                      final isAnyHeader = headerAttr != null;
                      final isQuote = selectionStyle.attributes.containsKey(quill.Attribute.blockQuote.key);
                      final isCodeBlock = selectionStyle.attributes.containsKey(quill.Attribute.codeBlock.key);

                      return Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildToolbarButton(Icons.undo_rounded, () => _quillController.undo()),
                                  _buildToolbarButton(Icons.redo_rounded, () => _quillController.redo()),
                                  _toolbarDivider(),
                                  MenuAnchor(
                                    alignmentOffset: const Offset(0, -180),
                                    menuChildren: [
                                      MenuItemButton(
                                        onPressed: () => _quillController.formatSelection(quill.Attribute.h1),
                                        child: Text('Heading 1', style: GoogleFonts.roboto()),
                                      ),
                                      MenuItemButton(
                                        onPressed: () => _quillController.formatSelection(quill.Attribute.h2),
                                        child: Text('Heading 2', style: GoogleFonts.roboto()),
                                      ),
                                      MenuItemButton(
                                        onPressed: () => _quillController.formatSelection(quill.Attribute.h3),
                                        child: Text('Heading 3', style: GoogleFonts.roboto()),
                                      ),
                                    ],
                                    builder: (context, controller, child) => _buildToolbarButton(
                                      Icons.format_size_rounded, 
                                      () => controller.isOpen ? controller.close() : controller.open(),
                                      isSelected: isAnyHeader,
                                    ),
                                  ),
                                  _buildToolbarButton(Icons.format_bold_rounded, () => _quillController.formatSelection(isBold ? quill.Attribute.clone(quill.Attribute.bold, null) : quill.Attribute.bold), isSelected: isBold),
                                  _buildToolbarButton(Icons.format_italic_rounded, () => _quillController.formatSelection(isItalic ? quill.Attribute.clone(quill.Attribute.italic, null) : quill.Attribute.italic), isSelected: isItalic),
                                  _buildToolbarButton(Icons.format_underlined_rounded, () => _quillController.formatSelection(isUnderline ? quill.Attribute.clone(quill.Attribute.underline, null) : quill.Attribute.underline), isSelected: isUnderline),
                                  _toolbarDivider(),
                                  _buildToolbarButton(Icons.format_list_bulleted_rounded, () => _quillController.formatSelection(isBullet ? quill.Attribute.clone(quill.Attribute.ul, null) : quill.Attribute.ul), isSelected: isBullet),
                                  _buildToolbarButton(Icons.format_list_numbered_rounded, () => _quillController.formatSelection(isOrdered ? quill.Attribute.clone(quill.Attribute.ol, null) : quill.Attribute.ol), isSelected: isOrdered),
                                  _buildToolbarButton(Icons.checklist_rtl_rounded, () => _quillController.formatSelection(isChecklist ? quill.Attribute.clone(quill.Attribute.unchecked, null) : quill.Attribute.unchecked), isSelected: isChecklist),
                                  _toolbarDivider(),
                                  _buildToolbarButton(Icons.format_quote_rounded, () => _quillController.formatSelection(isQuote ? quill.Attribute.clone(quill.Attribute.blockQuote, null) : quill.Attribute.blockQuote), isSelected: isQuote),
                                  _buildToolbarButton(Icons.code_rounded, () => _quillController.formatSelection(isCodeBlock ? quill.Attribute.clone(quill.Attribute.codeBlock, null) : quill.Attribute.codeBlock), isSelected: isCodeBlock),
                                  _toolbarDivider(),
                                  _buildToolbarButton(Icons.sell_outlined, () {
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
                                          _handleSave();
                                        },
                                      ),
                                    );
                                  }),
                                  _buildToolbarButton(Icons.image_outlined, _showImageSourceMenu),
                                  _buildToolbarButton(Icons.attach_file, _pickImage),
                                ],
                              ),
                            ),
                          ),
                          _toolbarDivider(),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildToolbarButton(Icons.keyboard_hide_rounded, () => FocusManager.instance.primaryFocus?.unfocus()),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarButton(
    IconData icon, 
    VoidCallback onTap, {
    bool isSelected = false,
    double iconSize = 18,
    double size = 36,
  }) {
    return SynqIconButton(
      icon: icon,
      onTap: onTap,
      isSelected: isSelected,
      iconSize: iconSize,
      size: size,
    );
  }

  Widget _toolbarDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 1, 
        height: 20, 
        color: Colors.grey.shade200,
      ),
    );
  }

  Future<void> _handleCustomPaste() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;
    final reader = await clipboard.read();

    // 1. Handle Images First
    if (reader.canProvide(Formats.png) || reader.canProvide(Formats.jpeg)) {
      final format = reader.canProvide(Formats.png) ? Formats.png : Formats.jpeg;
      final extension = format == Formats.png ? 'png' : 'jpg';

      final completer = Completer<Uint8List?>();
      reader.getFile(
        format,
        (file) async {
          try {
            final bytes = await file.readAll();
            completer.complete(bytes);
          } catch (_) {
            completer.complete(null);
          }
        },
        onError: (_) {
          completer.complete(null);
        },
      );
      final bytes = await completer.future;
      if (bytes != null) {
        final path = await _mediaService.saveBytesToLocalDocuments(
          bytes,
          extension: extension,
        );
        if (path != null) {
          _handleSingleImagePath(path);
          return;
        }
      }
    }

    // 2. Handle Rich HTML
    if (reader.canProvide(Formats.htmlText)) {
      final htmlStr = await reader.readValue(Formats.htmlText);
      if (htmlStr != null) {
        final parsedDoc = HtmlParser.deltaFromHtml(htmlStr);
        final selection = _quillController.selection;

        _quillController.replaceText(
          selection.start,
          selection.end - selection.start,
          parsedDoc.toDelta(),
          TextSelection.collapsed(offset: selection.start + parsedDoc.length),
        );
        return;
      }
    }

    // 3. Plain Text Fallback
    if (reader.canProvide(Formats.plainText)) {
      final text = await reader.readValue(Formats.plainText);
      if (text != null) {
        final selection = _quillController.selection;
        _quillController.replaceText(
          selection.start,
          selection.end - selection.start,
          text,
          TextSelection.collapsed(offset: selection.start + text.length),
        );
      }
    }
  }
}
