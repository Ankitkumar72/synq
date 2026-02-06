import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/navigation/fade_page_route.dart';
import '../../../agenda/presentation/meeting_agenda_screen.dart';

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
// ... keep rest unchanged or add if needed ...
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// ...
// ...
    }

    if (type == TaskType.active) {
       // ... active card ...
       // For now, only adding to standard as per primary requirement, 
       // but strictly "active" usually implies currently doing.
       // Only adding check for standard/admin/design to avoid cluttering specific active UI unless requested.
       return Container(
        // ...
// ...
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
          color: isCompleted ? AppColors.surface.withAlpha(150) : AppColors.surface, // Dim if completed
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
                      side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.5), width: 2),
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
                 // Use Transform to overlap the avatars instead of negative width
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
           
           // Show checkmark if completed (new addition)
           if (isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                   const Icon(Icons.check_circle, size: 16, color: AppColors.restGreen),
                   const SizedBox(width: 4),
                   Text(
                     'Completed', 
                     style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.restGreen)
                   ),
                ],
              )
           ],
        ],
      ),
      ),
    );
  }
}
