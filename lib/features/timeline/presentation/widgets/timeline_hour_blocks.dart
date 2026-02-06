import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../../domain/models/timeline_event.dart';
import '../widgets/timeline_task_card.dart';

class TimelineHourBlocks extends ConsumerStatefulWidget {
  const TimelineHourBlocks({super.key});

  @override
  ConsumerState<TimelineHourBlocks> createState() => _TimelineHourBlocksState();
}

class _TimelineHourBlocksState extends ConsumerState<TimelineHourBlocks> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _currentHourKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentHour();
    });
  }
  
  void _scrollToCurrentHour() {
    if (_currentHourKey.currentContext != null) {
      Scrollable.ensureVisible(
        _currentHourKey.currentContext!,
        alignment: 0.3, // Top 30% of screen
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(timelineEventsProvider);
    final now = DateTime.now();
    
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.beach_access, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No tasks today',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Enjoy your free time!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary.withAlpha(150)),
            ),
          ],
        ),
      );
    }
        
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        children: List.generate(24, (hour) {
          final isCurrentHour = now.hour == hour;
          
          final hourEvents = events.where((e) {
             final startMin = _parseToMinutes(e.startTime);
             final endMin = _parseToMinutes(e.endTime);
             final hourStartMin = hour * 60;
             final hourEndMin = (hour + 1) * 60;
             
             return (startMin >= hourStartMin && startMin < hourEndMin) ||
                    (startMin < hourStartMin && endMin > hourStartMin);
          }).toList();
          
          return Container(
            key: isCurrentHour ? _currentHourKey : null,
            decoration: BoxDecoration(
              color: isCurrentHour 
                ? AppColors.primary.withValues(alpha: 0.05) 
                : Colors.transparent,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      _formatHour(hour),
                      style: TextStyle(
                        fontSize: 14,
                        color: isCurrentHour ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isCurrentHour 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                      ),
                    ),
                  ),
                  
                  Expanded(
                    child: Column(
                      children: [
                         if (hourEvents.isEmpty)
                           const SizedBox(height: 24),
                           
                        ...hourEvents.map((event) => 
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: TimelineTaskCard(
                              title: event.title,
                              subtitle: event.subtitle,
                              timeRange: '${event.startTime} - ${event.endTime}',
                              type: _mapType(event.type),
                              tag: event.tag,
                              isCompleted: event.isCompleted,
                              onToggleCompletion: (_) => ref.read(timelineEventsProvider.notifier).toggleEventCompletion(event.id),
                            ),
                          )
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
  
  TaskType _mapType(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.active: return TaskType.active;
      case TimelineEventType.rest: return TaskType.rest;
      case TimelineEventType.strategy: return TaskType.strategy;
      case TimelineEventType.admin: return TaskType.admin;
      case TimelineEventType.design: return TaskType.design;
      default: return TaskType.standard;
    }
  }

  int _parseToMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(RegExp(r'[:\s]'));
      if (parts.isEmpty) return 0;
      
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      bool isPm = parts.length > 2 && parts[2].toLowerCase() == 'pm';
      
      if (isPm && h != 12) h += 12;
      if (!isPm && h == 12) h = 0;
      
      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }
  
  String _formatHour(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour $period';
  }
}
