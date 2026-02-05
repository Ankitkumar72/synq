import 'package:flutter/material.dart';
import '../widgets/timeline_header.dart';
import '../widgets/timeline_task_card.dart';
import '../widgets/timeline_connector.dart';
import '../../../../core/theme/app_theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/timeline_provider.dart';
import '../../domain/models/timeline_event.dart';
import '../../../home/presentation/widgets/create_new_sheet.dart';

class DailyTimelinePage extends ConsumerWidget {
  const DailyTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(timelineEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with total task count from provider if desired, 
            // for now kept static/or slightly dynamic based on list length? 
            // Let's keep the existing header visually but we could pass count.
            // Header with total task count from provider
            TimelineHeader(
              remainingTasks: events.where((e) => !e.isCompleted).length,
              date: DateTime.now(),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: events.length + 1, // +1 for extra space
                itemBuilder: (context, index) {
                  if (index == events.length) {
                    return const SizedBox(height: 80); // Bottom padding for FAB
                  }

                  final event = events[index];
                  final isLast = index == events.length - 1;

                  // Determine TaskType from event type
                  TaskType cardType = TaskType.standard; // Default
                  switch (event.type) {
                    case TimelineEventType.strategy: cardType = TaskType.strategy; break;
                    case TimelineEventType.active: cardType = TaskType.active; break;
                    case TimelineEventType.rest: cardType = TaskType.rest; break;
                    case TimelineEventType.standard: cardType = TaskType.standard; break;
                    case TimelineEventType.admin: cardType = TaskType.admin; break;
                    case TimelineEventType.design: cardType = TaskType.design; break;
                  }

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // TIME COLUMN
                        SizedBox(
                          width: 60,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 0), // Align with top of card
                            child: Text(
                              event.startTime,
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // CONNECTOR
                        TimelineConnector(
                          isLast: isLast, 
                          isActive: event.isCurrent,
                        ),
                        const SizedBox(width: 12),
                        
                        // CARD CONTENT
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 32.0),
                            child: TimelineTaskCard(
                              title: event.title,
                              subtitle: event.subtitle,
                              timeRange: '${event.startTime} - ${event.endTime}',
                              type: cardType,
                              tag: event.tag,
                              isCompleted: event.isCompleted,
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateNewSheet(context),
        backgroundColor: AppColors.accentPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
