import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/navigation/fade_page_route.dart';

enum TaskType { strategy, active, rest, standard, admin, design }

class TimelineTaskCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String timeRange;
  final TaskType type;
  final String? tag;
  final bool isCompleted;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onToggleCompletion;

  const TimelineTaskCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.timeRange,
    required this.type,
    this.tag,
    this.isCompleted = false,
    this.onTap,
    this.onToggleCompletion,
  });

  @override
  Widget build(BuildContext context) {
    return _buildCard(context);
  }

  Widget _buildCard(BuildContext context) {
    if (type == TaskType.rest) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(100), // Pill shape
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.restGreen,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.restGreenBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'AI Suggested',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.restGreen,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            if (isCompleted) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 16, color: AppColors.textSecondary),
            ],
          ],
        ),
      );
    }

    if (type == TaskType.active) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.activeCardBg,
           border: Border(
             left: BorderSide(color: AppColors.activeCardBorder, width: 4),
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            topLeft: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CURRENT BLOCK',
                   style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                ),
            ],
          ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            if (subtitle != null)
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    // Standard Card
    Color? tagBg;
    Color? tagText;
    
    if (type == TaskType.strategy) {
      tagBg = AppColors.tagStrategy;
      tagText = AppColors.textStrategy;
    } else if (type == TaskType.design) {
      tagBg = AppColors.tagDesign;
      tagText = AppColors.textDesign;
    } else if (type == TaskType.admin) {
      tagBg = AppColors.tagAdmin;
      tagText = AppColors.textAdmin;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.surface.withAlpha(150) : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (onToggleCompletion != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: isCompleted,
                      onChanged: onToggleCompletion,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      activeColor: AppColors.primary,
                      side: BorderSide(color: AppColors.textSecondary.withAlpha(128), width: 2),
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted ? AppColors.textSecondary : null,
                      ),
                ),
              ),
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tagBg ?? Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag!.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tagText ?? Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
               Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
               const SizedBox(width: 6),
               Text(
                 timeRange,
                 style: Theme.of(context).textTheme.bodySmall?.copyWith(
                   color: AppColors.textSecondary,
                 ),
               ),
            ],
          ),
          if (subtitle != null) ...[
             const SizedBox(height: 8),
             Text(
               subtitle!,
               style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                 color: AppColors.textSecondary,
               ),
             ),
          ],
           if (type == TaskType.admin) ...[
             const SizedBox(height: 12),
             Row(
               children: [
                 Container(
                   padding: const EdgeInsets.all(4),
                   decoration: BoxDecoration(
                     color: Colors.grey.shade200,
                     shape: BoxShape.circle,
                   ),
                   child: const Text('S', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                 ),
                 Transform.translate(
                   offset: const Offset(-6, 0),
                   child: Container(
                     padding: const EdgeInsets.all(4),
                     decoration: BoxDecoration(
                       color: Colors.blue.shade100,
                       shape: BoxShape.circle,
                       border: Border.all(color: Colors.white, width: 1),
                     ),
                     child: const Text('M', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Text(
                   'Clear inbox zero',
                   style: Theme.of(context).textTheme.bodySmall?.copyWith(
                     color: AppColors.textSecondary,
                   ),
                 ),
               ],
             ),
           ],
        ],
      ),
      ),
    );
  }
}
