import 'package:flutter/material.dart';
import '../widgets/timeline_header.dart';
import '../widgets/timeline_task_card.dart';
import '../widgets/timeline_connector.dart';
import '../../../../core/theme/app_theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/timeline_provider.dart';
import '../../domain/models/timeline_event.dart';
import '../../../home/presentation/widgets/create_new_sheet.dart';
import '../../../notes/data/notes_provider.dart'; // Support task toggle
import '../../../../core/theme/app_theme.dart'; // Ensure theme access

class DailyTimelinePage extends ConsumerStatefulWidget {
  const DailyTimelinePage({super.key});

  @override
  ConsumerState<DailyTimelinePage> createState() => _DailyTimelinePageState();
}

class _DailyTimelinePageState extends ConsumerState<DailyTimelinePage> {
  final List<GlobalKey> _itemKeys = [];

  @override
  void initState() {
    super.initState();
  }

  void _scrollToCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final events = ref.read(timelineEventsProvider);
      final currentIndex = events.indexWhere((e) => e.isCurrent);
      
      if (currentIndex != -1 && currentIndex < _itemKeys.length) {
        final key = _itemKeys[currentIndex];
        if (key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            alignment: 0.3, // Position item at top-third of screen
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(timelineEventsProvider);

    // Ensure we have enough keys
    while (_itemKeys.length < events.length) {
      _itemKeys.add(GlobalKey());
    }
    
    // Attempt scroll after every build (if current item changes)
    _scrollToCurrent();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            TimelineHeader(
              remainingTasks: events.where((e) => !e.isCompleted).length,
              date: DateTime.now(),
            ),
            Expanded(
              child: events.isEmpty 
                  ? _buildEmptyState(context)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          for (int i = 0; i < events.length; i++) ...[
                            _buildTimelineItem(context, ref, events[i], i, events.length),
                          ],
                          const SizedBox(height: 80), // Bottom padding
                        ],
                      ),
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentPurple.withValues(alpha: 0.1), width: 4),
            ),
            child: Icon(Icons.spa_rounded, size: 48, color: AppColors.accentPurple.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          Text(
            'Free Time',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'No tasks scheduled for today.\nTake a deep breath.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: () => showCreateNewSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Task'),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentPurple),
          )
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, WidgetRef ref, TimelineEvent event, int index, int total) {
    final isLast = index == total - 1;

    TaskType cardType = TaskType.standard;
    switch (event.type) {
      case TimelineEventType.strategy: cardType = TaskType.strategy; break;
      case TimelineEventType.active: cardType = TaskType.active; break;
      case TimelineEventType.rest: cardType = TaskType.rest; break;
      case TimelineEventType.standard: cardType = TaskType.standard; break;
      case TimelineEventType.admin: cardType = TaskType.admin; break;
      case TimelineEventType.design: cardType = TaskType.design; break;
    }

    return Container(
      key: _itemKeys[index],
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TIME COLUMN
            SizedBox(
              width: 60,
              child: Padding(
                padding: const EdgeInsets.only(top: 0),
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
                  onTap: () {
                     // Parse ID "task_123" -> "123"
                     if (event.id.startsWith('task_')) {
                        final taskId = event.id.substring(5); // Remove "task_" prefix
                        ref.read(notesProvider.notifier).toggleCompleted(taskId);
                     }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
