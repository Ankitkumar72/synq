import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/note.dart';

class NoteOptionsSheet extends StatelessWidget {
  final Note note;
  final VoidCallback? onClose;
  final VoidCallback? onToggleReadingView;
  final bool isReadOnly;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final VoidCallback? onFind;
  final VoidCallback? onReplace;

  const NoteOptionsSheet({
    super.key,
    required this.note,
    this.onClose,
    this.onToggleReadingView,
    this.isReadOnly = false,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
    this.onFind,
    this.onReplace,
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
          // Header
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isEmpty ? 'Untitled' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last edited ${note.updatedAt != null ? _formatDateTime(note.updatedAt) : 'Never'}',
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
          
          // Group 1: Navigation Actions (Close/Reading View)
          if (onClose != null || onToggleReadingView != null)
            _OptionGroup(
              children: [
                if (onClose != null)
                  _OptionItem(
                    icon: Icons.close,
                    label: 'Close',
                    onTap: onClose!,
                  ),
                if (onToggleReadingView != null)
                  _OptionItem(
                    icon: isReadOnly ? Icons.edit_outlined : Icons.chrome_reader_mode_outlined,
                    label: isReadOnly ? 'Edit view' : 'Reading view',
                    onTap: onToggleReadingView!,
                  ),
              ],
            ),

          // Group 2: Management Actions
          _OptionGroup(
            children: [
              _OptionItem(
                icon: Icons.edit_outlined,
                label: 'Rename...',
                onTap: onRename,
              ),
              _OptionItem(
                icon: Icons.drive_file_move_outlined,
                label: 'Move file to...',
                onTap: onMove,
              ),
              if (onFind != null)
                _OptionItem(
                  icon: Icons.search,
                  label: 'Find...',
                  onTap: onFind!,
                ),
              if (onReplace != null)
                _OptionItem(
                  icon: Icons.find_replace,
                  label: 'Replace...',
                  onTap: onReplace!,
                ),
            ],
          ),

          // Group 3: Destructive Actions
          _OptionGroup(
            children: [
              _OptionItem(
                icon: Icons.delete_outline,
                label: 'Delete file',
                isDestructive: true,
                onTap: onDelete,
              ),
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Never';
    // Simple mock formatting
    return '${dt.day}/${dt.month}/${dt.year}';
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

  const _OptionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
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
              Icon(icon, color: isDestructive ? Colors.red : Colors.black54, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
