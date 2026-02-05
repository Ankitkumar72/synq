import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/timeline_event.dart';

final timelineEventsProvider = NotifierProvider<TimelineEventsNotifier, List<TimelineEvent>>(() {
  return TimelineEventsNotifier();
});

class TimelineEventsNotifier extends Notifier<List<TimelineEvent>> {
  @override
  List<TimelineEvent> build() {
    final now = DateTime.now();
    final _hour = now.hour;
    
    // Helper to format time
    String fmt(int h, int m) {
      final dt = DateTime(now.year, now.month, now.day, h, m);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $ampm';
    }

    return [
      TimelineEvent(
        id: '1',
        title: 'Strategy Planning',
        startTime: fmt(9, 0),
        endTime: fmt(10, 30),
        type: TimelineEventType.strategy,
        tag: 'STRATEGY',
        isCompleted: _hour >= 11,
      ),
      TimelineEvent(
        id: '2',
        title: 'Rest Break',
        startTime: fmt(10, 30), 
        endTime: fmt(10, 45), 
        type: TimelineEventType.rest,
        subtitle: 'Recharge before deep work.',
        isCompleted: _hour >= 11,
      ),
      TimelineEvent(
        id: '3',
        title: 'Deep Work Block',
        subtitle: 'Focus: Core Architecture',
        startTime: fmt(11, 0),
        endTime: fmt(13, 0),
        type: TimelineEventType.active,
        isCurrent: _hour >= 11 && _hour < 13,
        isCompleted: _hour >= 13,
      ),
      TimelineEvent(
        id: '4',
        title: 'Lunch',
        subtitle: 'Free time',
        startTime: fmt(13, 0),
        endTime: fmt(14, 0),
        type: TimelineEventType.standard,
        isCompleted: _hour >= 14,
      ),
      TimelineEvent(
        id: '5',
        title: 'Team Sync',
        subtitle: 'Weekly Standup',
        startTime: fmt(14, 0),
        endTime: fmt(15, 0),
        type: TimelineEventType.admin,
        tag: 'MEETING',
        isCompleted: _hour >= 15,
      ),
      TimelineEvent(
        id: '6',
        title: 'Design Review',
        startTime: fmt(16, 0),
        endTime: fmt(17, 30),
        type: TimelineEventType.design,
        tag: 'DESIGN',
        isCompleted: _hour >= 18,
      ),
    ];
  }

  void addTask(TimelineEvent event) {
    state = [...state, event];
  }
}
