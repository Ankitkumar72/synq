import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../domain/models/folder.dart';

class FolderCard extends StatelessWidget {
  final Folder folder;
  final int itemCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress; // Added for options menu
  final VoidCallback? onEdit; // Added for edit option

  const FolderCard({
    super.key,
    required this.folder,
    required this.itemCount,
    required this.onTap,
    this.onLongPress,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        if (onLongPress != null) {
          HapticFeedback.mediumImpact();
          onLongPress!();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100), // Rounded pill shape
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32, 
              height: 32,
              decoration: BoxDecoration(
                color: Color(folder.colorValue).withValues(alpha: 0.12),
                shape: BoxShape.circle, 
              ),
              child: Icon(
                IconUtils.getIconFromCodePoint(folder.iconCodePoint),
                color: Color(folder.colorValue),
                size: 16, 
              ),
            ),
            const SizedBox(width: 12), 
            Text(
              folder.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
              maxLines: 2, 
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(), 
            Text(
              '$itemCount', 
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14, 
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (folder.isFavorite) ...[
                const SizedBox(width: 4),
                const Icon(Icons.star_rounded, color: Colors.orange, size: 12),
            ],
          ],
        ),
      ),
    );
  }
}
