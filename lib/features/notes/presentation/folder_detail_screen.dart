import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../domain/models/folder.dart';
import '../data/notes_provider.dart';
import '../../../../core/navigation/fade_page_route.dart';
import 'note_detail_screen.dart'; 
// We will need to update creation sheets to accept a pre-selected folderId
// For now, let's list items.

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          folder.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              // Options: Edit Folder, Delete Folder
              _showOptions(context, ref);
            },
          ),
        ],
      ),
      body: folderNotes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(
                    IconData(folder.iconCodePoint, fontFamily: folder.iconFontFamily ?? 'MaterialIcons'),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  color: AppColors.surface,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(folder.colorValue).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        note.isTask ? Icons.check_circle_outlined : Icons.description_outlined,
                        color: Color(folder.colorValue),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      note.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: note.body != null && note.body!.isNotEmpty 
                        ? Text(note.body!, maxLines: 1, overflow: TextOverflow.ellipsis) 
                        : null,
                    trailing: Text(
                      _formatDate(note.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
            // Open crate note sheet with pre-selected folder
            // We need to update CreateNoteSheet to accept initialFolderId
            // For now just open it
            Navigator.push(
              context,
              FadePageRoute(builder: (_) => NoteDetailScreen(initialFolderId: folder.id)),
            );
        },
        backgroundColor: Color(folder.colorValue),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}';
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    // TODO: Implement Edit/Delete
  }
}
