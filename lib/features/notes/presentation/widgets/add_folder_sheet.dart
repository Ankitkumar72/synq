import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../domain/models/folder.dart';
import '../../data/folder_provider.dart';

class AddFolderSheet extends ConsumerStatefulWidget {
  final Folder? folderToEdit;

  const AddFolderSheet({super.key, this.folderToEdit});

  @override
  ConsumerState<AddFolderSheet> createState() => _AddFolderSheetState();
}

class _AddFolderSheetState extends ConsumerState<AddFolderSheet> {
  final _nameController = TextEditingController();
  int _selectedColor = 0xFF2196F3; // Default Blue
  IconData _selectedIcon = Icons.folder;
  bool _isFavorite = false;

  final List<int> _colors = [
    0xFF2196F3, // Blue
    0xFFF44336, // Red
    0xFF4CAF50, // Green
    0xFFFFC107, // Amber
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
    0xFFFF5722, // Deep Orange
    0xFF607D8B, // Blue Grey
  ];

  final List<IconData> _icons = IconUtils.supportedIcons;

  @override
  void initState() {
    super.initState();
    if (widget.folderToEdit != null) {
      _nameController.text = widget.folderToEdit!.name;
      _selectedColor = widget.folderToEdit!.colorValue;
      _selectedIcon = IconUtils.getIconFromCodePoint(widget.folderToEdit!.iconCodePoint);
      _isFavorite = widget.folderToEdit!.isFavorite;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a folder name')),
      );
      return;
    }

    final folder = Folder(
      id: widget.folderToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      iconCodePoint: _selectedIcon.codePoint,
      iconFontFamily: _selectedIcon.fontFamily,
      colorValue: _selectedColor,
      createdAt: widget.folderToEdit?.createdAt ?? DateTime.now(),
      isFavorite: _isFavorite,
    );

    if (widget.folderToEdit == null) {
      await ref.read(foldersProvider.notifier).addFolder(folder);
    } else {
      await ref.read(foldersProvider.notifier).updateFolder(folder);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
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
            const SizedBox(height: 24),
            Text(
              widget.folderToEdit == null ? 'New Folder' : 'Edit Folder',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // Explicit black
                  ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.black), // Explicit black text
              decoration: InputDecoration(
                hintText: 'Folder Name',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              maxLines: null, // Allow wrapping
              textCapitalization: TextCapitalization.sentences, // Cap first letter
            ),
            const SizedBox(height: 24),
            Text('Color', style: Theme.of(context).textTheme.titleSmall!.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _colors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final color = _colors[index];
                  final isSelected = color == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text('Icon', style: Theme.of(context).textTheme.titleSmall!.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _icons.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final icon = _icons[index];
                  final isSelected = icon == _selectedIcon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                      ),
                      child: Icon(icon, color: isSelected ? AppColors.primary : Colors.grey[600]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // Favorite Toggle
            SwitchListTile(
              title: const Text(
                'Add to Favorites',
                style: TextStyle(color: Colors.black), // Explicit black
              ),
              value: _isFavorite,
              onChanged: (val) => setState(() => _isFavorite = val),
              contentPadding: EdgeInsets.zero,
              activeTrackColor: const Color(0xFF5473F7), // Task blue
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Create Folder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showAddFolderSheet(BuildContext context, {Folder? folderToEdit}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddFolderSheet(folderToEdit: folderToEdit),
  );
}
