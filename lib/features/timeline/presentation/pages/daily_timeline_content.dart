import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../widgets/timeline_header.dart';
import '../widgets/timeline_connector.dart';
import '../widgets/timeline_task_card.dart';


/// Timeline page content without bottom navigation bar (for use in MainShell)
class DailyTimelineContent extends ConsumerWidget {
  const DailyTimelineContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(timelineEventsProvider);
    
    return SafeArea(
      child: Column(
        children: [
          TimelineHeader(
            remainingTasks: events.where((e) => !e.isCompleted).length,
            date: DateTime.now(),
          ),
          if (events.isEmpty)
             Expanded(
               child: Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(Icons.beach_access, size: 64, color: Colors.grey.shade300),
                     const SizedBox(height: 16),
                     Text(
                       'No tasks today — enjoy your free time!',
                       style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                         color: AppColors.textSecondary,
                       ),
                       textAlign: TextAlign.center,
                     ),

                   ],
                 ),
               ),
             )
          else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final isLast = index == events.length - 1;
                
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Time Column
                      SizedBox(
                        width: 60,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            event.startTime,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: event.isCurrent 
                                  ? AppColors.primary 
                                  : AppColors.textSecondary,
                              fontWeight: event.isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      
                      // Timeline Connector
                      TimelineConnector(
                        isLast: isLast,
                        isActive: event.isCurrent,
                      ),
                      
                      // Task Card
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                          child: TimelineTaskCard(
                            title: event.title,
                            subtitle: event.subtitle,
                            timeRange: '${event.startTime} - ${event.endTime}',
                            type: TaskType.values.byName(event.type.name),
                            tag: event.tag,
                            isCompleted: event.isCompleted,
                            // Pass the toggle callback
                            onToggleCompletion: (_) {
                              ref.read(timelineEventsProvider.notifier).toggleEventCompletion(event.id);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
