import 'package:flutter/material.dart';
import '../../domain/models/folder.dart';

class FolderOptionsSheet extends StatelessWidget {
  final Folder folder;
  final int noteCount;
  final int folderCount;
  final VoidCallback onNewNote;
  final VoidCallback onNewFolder;
  final VoidCallback onMakeCopy;
  final VoidCallback onMove;
  final VoidCallback onBookmark;
  final VoidCallback onCopyPath;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSearch;

  const FolderOptionsSheet({
    super.key,
    required this.folder,
    required this.noteCount,
    required this.folderCount,
    required this.onNewNote,
    required this.onNewFolder,
    required this.onMakeCopy,
    required this.onMove,
    required this.onBookmark,
    required this.onCopyPath,
    required this.onRename,
    required this.onDelete,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Header Section
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$noteCount files, $folderCount folders',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Group 1: Creation
          _OptionGroup(
            children: [
              _OptionItem(
                icon: Icons.edit_note_outlined,
                label: 'New note',
                onTap: onNewNote,
              ),
              _OptionItem(
                icon: Icons.create_new_folder_outlined,
                label: 'New folder',
                onTap: onNewFolder,
              ),
            ],
          ),
          // Group 2: Management
          _OptionGroup(
            children: [
              _OptionItem(
                icon: Icons.copy_outlined,
                label: 'Make a copy',
                onTap: onMakeCopy,
              ),
              _OptionItem(
                icon: Icons.drive_file_move_outlined,
                label: 'Move folder to...',
                onTap: onMove,
              ),
              _OptionItem(
                icon: Icons.bookmark_outline,
                label: 'Bookmark...',
                onTap: onBookmark,
              ),
            ],
          ),
          // Group 3: Utility
          _OptionGroup(
            children: [
              _OptionItem(
                icon: Icons.link,
                label: 'Copy path',
                onTap: onCopyPath,
                showChevron: true,
              ),
            ],
          ),
          // Group 4: Edit
          _OptionGroup(
            children: [
              _OptionItem(
                icon: Icons.edit_outlined,
                label: 'Rename...',
                onTap: onRename,
              ),
              _OptionItem(
                icon: Icons.delete_outline,
                label: 'Delete',
                isDestructive: true,
                onTap: onDelete,
              ),
            ],
          ),
          // Group 5: Search
          _OptionGroup(
            children: [
              _OptionItem(
                icon: Icons.search,
                label: 'Search in folder',
                onTap: onSearch,
              ),
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionGroup extends StatelessWidget {
  final List<Widget> children;

  const _OptionGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          if (index == children.length - 1) return children[index];
          return Column(
            children: [
              children[index],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.grey[300],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool showChevron;

  const _OptionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : Colors.black;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
