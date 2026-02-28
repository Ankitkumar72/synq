import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synq/core/theme/app_theme.dart';
import 'package:synq/features/notes/data/notes_provider.dart';
import 'package:synq/features/notes/data/folder_provider.dart';
import 'package:synq/features/notes/domain/models/folder.dart';
import 'package:synq/features/notes/domain/models/note.dart';
import 'package:synq/core/navigation/fade_page_route.dart';
import 'package:synq/core/utils/icon_utils.dart';
import 'package:synq/features/notes/presentation/note_detail_screen.dart';
import 'package:synq/features/notes/presentation/widgets/delete_confirmation_sheet.dart';
import 'package:synq/features/notes/presentation/widgets/note_options_sheet.dart';

class FolderDetailScreen extends ConsumerWidget {
  final Folder folder;

  const FolderDetailScreen({super.key, required this.folder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final allNotes = notesAsync.value ?? [];
    final folderNotes = allNotes.where((n) => n.folderId == folder.id).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        toolbarHeight: 80, // Increased height
        leading: Padding(
          padding: const EdgeInsets.only(top: 15),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(top: 15),
          child: Text(
            folder.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        centerTitle: true, // Center the title
      ),
      body: folderNotes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    IconUtils.getIconFromCodePoint(folder.iconCodePoint),
                    size: 64,
                    color: Color(folder.colorValue).withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No items yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: folderNotes.length,
              itemBuilder: (context, index) {
                final note = folderNotes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  color: AppColors.surface,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0, // Reduced from 8
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(6), // Reduced from 8
                      decoration: BoxDecoration(
                        color: Color(folder.colorValue).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        note.isTask
                            ? Icons.check_circle_outlined
                            : Icons.description_outlined,
                        color: Color(folder.colorValue),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      note.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black, // Explicit black
                      ),
                    ),
                    subtitle: note.body != null && note.body!.isNotEmpty
                        ? Text(
                            note.body!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis, // Keep 1 line
                            style: const TextStyle(
                              color: Colors.black87, // Visible dark color
                            ),
                          )
                        : null,
                    trailing: Text(
                      _formatDateString(note.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        FadePageRoute(
                          builder: (_) => NoteDetailScreen(
                            noteToEdit: note,
                            initialFolderId: folder.id,
                          ),
                        ),
                      );
                    },
                    onLongPress: () => _showNoteOptionsMenu(context, ref, note),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            FadePageRoute(
              builder: (_) => NoteDetailScreen(initialFolderId: folder.id),
            ),
          );
        },
        backgroundColor: Color(folder.colorValue),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String _formatDateString(DateTime dt) {
    return '${dt.day}/${dt.month}';
  }

  void _showNoteOptionsMenu(BuildContext context, WidgetRef ref, Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => NoteOptionsSheet(
        note: note,
        onRename: () {
          Navigator.push(
            context,
            FadePageRoute(
              builder: (_) => NoteDetailScreen(
                noteToEdit: note,
                initialFolderId: folder.id,
              ),
            ),
          );
        },
        onMove: () {
          _openFolderPicker(context, ref, note);
        },
        onDelete: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (confirmSheetContext) => DeleteConfirmationSheet(
              itemName: note.title.isEmpty ? 'Untitled' : note.title,
              onDelete: () {
                ref.read(notesProvider.notifier).deleteNote(note.id);
              },
              onDeleteAndDontAsk: () {
                // For now, same as delete
                ref.read(notesProvider.notifier).deleteNote(note.id);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openFolderPicker(BuildContext context, WidgetRef ref, Note note) async {
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
                const SizedBox(height: 16),
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
                          leading: const Icon(Icons.folder_off_outlined, color: Colors.grey),
                          title: const Text('Uncategorized', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          trailing: note.folderId == null ? const Icon(Icons.check, color: Color(0xFF5473F7)) : null,
                          onTap: () => Navigator.pop(context, uncategorizedValue),
                        ),
                        const Divider(height: 1),
                        ...folders.map((f) {
                          final isSelected = note.folderId == f.id;
                          return ListTile(
                            leading: Icon(
                              IconUtils.getIconFromCodePoint(f.iconCodePoint),
                              color: Color(f.colorValue),
                            ),
                            title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                            trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF5473F7)) : null,
                            onTap: () => Navigator.pop(context, f.id),
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

    if (selected == null) return;
    final nextFolderId = selected == uncategorizedValue ? null : selected;
    if (nextFolderId == note.folderId) return;

    await ref.read(notesProvider.notifier).updateNote(note.copyWith(folderId: nextFolderId));

    if (context.mounted) {
      final folderName = nextFolderId == null 
          ? 'Uncategorized' 
          : folders.any((f) => f.id == nextFolderId)
              ? folders.firstWhere((f) => f.id == nextFolderId).name
              : 'Folder';
      
      final fileName = note.title.isEmpty ? 'Untitled' : note.title;
      _showToast(context, '$fileName Moved to $folderName.');
    }
  }

  void _showToast(BuildContext context, String message) {
    debugPrint('SHOWING TOAST: $message'); // Debug log
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 120, // Clearly below status bar and app bar
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
                border: Border.all(color: const Color(0xFF5473F7).withValues(alpha: 0.5), width: 1.5),
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
                  color: Colors.black, // High contrast black text
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
}
