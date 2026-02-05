import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';

class TimelineHeader extends ConsumerWidget {
  final int remainingTasks;
  final DateTime date;

  const TimelineHeader({
    super.key, 
    required this.remainingTasks,
    required this.date,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Format date: "Mon, Oct 24"
    // Using basic formatting for now to avoid intl dependency if not already set up, 
    // or we can use generic formatting logic. 
    // Let's use a simple helper or assume Intl is available if we saw it in pubspec.
    // I saw intl in pubspec earlier (0.19.0).
    final dateStr = _formatDate(date);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '$remainingTasks tasks remaining',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface, // Placeholder for avatar
            ),
             child: const Icon(Icons.person_outline, color: AppColors.textPrimary), // Placeholder icon
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    final day = date.day;
    
    return '$weekday, $month $day';
  }
}
