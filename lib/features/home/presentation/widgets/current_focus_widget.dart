
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/current_focus_provider.dart';
import '../../../notes/domain/models/note.dart';

class CurrentFocusWidget extends ConsumerWidget {
  const CurrentFocusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Note?> focusAsync = ref.watch(currentFocusProvider);
    final progress = ref.watch(currentFocusProgressProvider);
    final timeRemaining = ref.watch(currentFocusTimeRemainingProvider);
    
    return focusAsync.when(
      data: (focus) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
             BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: AppColors.primary, size: 8),
                      const SizedBox(width: 6),
                      Text('CURRENT FOCUS', 
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10, 
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Show Time Slot if available
                if (focus != null && focus.scheduledTime != null && focus.endTime != null)
                   Text(
                    '${_formatTime(focus.scheduledTime!)} - ${_formatTime(focus.endTime!)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Task title or "Free Time"
            Text(
              focus?.title ?? 'Free Time',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              focus != null 
                ? (focus.category.name.toUpperCase())
                : 'No upcoming tasks. Good time to plan or rest.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            
            const SizedBox(height: 24),
            
            // Animated progress bar with Timer on the right
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      minHeight: 6,
                    ),
                  ),
                ),
                if (focus != null) ...[
                  const SizedBox(width: 12),
                   Text(
                    timeRemaining,
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 14, 
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()], // Fixed width numbers
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      loading: () => _buildShimmer(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildShimmer() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(child: CircularProgressIndicator(color: Colors.white24)),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
