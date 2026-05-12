import 'package:flutter_test/flutter_test.dart';
import 'package:synq/features/timeline/domain/models/timeline_event.dart';
import 'package:synq/features/timeline/presentation/widgets/timeline_layout_engine.dart';

void main() {
  group('TimelineLayoutEngine High-Density & GCal Logic Tests', () {
    
    test('Test 1: 10 Events + 1 Task Group in 1 Hour (Density 11)', () {
      final events = <TimelineEvent>[];
      // 10 Events 1:00 PM - 2:00 PM
      for (int i = 0; i < 10; i++) {
        events.add(TimelineEvent(
          id: 'event_$i',
          title: 'Event $i',
          startTime: '1:00 PM',
          endTime: '2:00 PM',
          type: TimelineEventType.standard,
        ));
      }
      // 1 Task Group 1:00 PM - 2:00 PM (emulated)
      events.add(TimelineEvent(
        id: 'task_group',
        title: 'Tasks',
        startTime: '1:00 PM',
        endTime: '2:00 PM',
        type: TimelineEventType.standard,
        kind: EventKind.taskGroup,
      ));

      final positioned = TimelineLayoutEngine.calculatePositions(
        events: events,
        containerWidth: 1000,
      );

      expect(positioned.length, 11);
      for (final p in positioned) {
        // Each should have maxOverlap of 11
        expect(p.totalColumns, 11);
        // Width should be (1000 / 11) - gap
        expect(p.width, closeTo(1000 / 11 - 4.0, 0.1));
      }
      
      // Verify columns are 0 to 10
      final cols = positioned.map((p) => p.column).toSet();
      expect(cols.length, 11);
      expect(cols, containsAll(Iterable.generate(11)));
    });

    test('Test 1b: 10 Events + 10 Tasks in 1 Hour (Density 20)', () {
      final events = <TimelineEvent>[];
      // 10 Events 2:00 PM - 3:00 PM
      for (int i = 0; i < 10; i++) {
        events.add(TimelineEvent(
          id: 'event_$i',
          title: 'Event $i',
          startTime: '2:00 PM',
          endTime: '3:00 PM',
          type: TimelineEventType.standard,
        ));
      }
      // 10 Tasks 2:00 PM - 3:00 PM
      for (int i = 0; i < 10; i++) {
        events.add(TimelineEvent(
          id: 'task_$i',
          title: 'Task $i',
          startTime: '2:00 PM',
          endTime: '3:00 PM',
          type: TimelineEventType.standard,
          kind: EventKind.task,
        ));
      }

      final positioned = TimelineLayoutEngine.calculatePositions(
        events: events,
        containerWidth: 1000,
      );

      expect(positioned.length, 20);
      for (final p in positioned) {
        expect(p.totalColumns, 20);
        // At 1000px, 20 columns = 50px each. -4px gap = 46px.
        expect(p.width, closeTo(1000 / 20 - 4.0, 0.1));
      }
      
      final cols = positioned.map((p) => p.column).toSet();
      expect(cols.length, 20);
      expect(cols, containsAll(Iterable.generate(20)));
    });

    test('Test 2: Staircase Cluster (A-B, B-C, no A-C)', () {
      final events = [
        const TimelineEvent(
          id: 'A',
          title: 'A',
          startTime: '1:00 PM',
          endTime: '2:00 PM',
          type: TimelineEventType.standard,
        ),
        const TimelineEvent(
          id: 'B',
          title: 'B',
          startTime: '1:30 PM',
          endTime: '2:30 PM',
          type: TimelineEventType.standard,
        ),
        const TimelineEvent(
          id: 'C',
          title: 'C',
          startTime: '2:00 PM',
          endTime: '3:00 PM',
          type: TimelineEventType.standard,
        ),
      ];

      final positioned = TimelineLayoutEngine.calculatePositions(
        events: events,
        containerWidth: 1000,
      );

      // A and B overlap. B and C overlap. All in one cluster.
      // Max density in cluster is 2 (A,B or B,C).
      for (final p in positioned) {
        expect(p.totalColumns, 2);
      }
      
      final eventA = positioned.firstWhere((p) => p.event.id == 'A');
      final eventB = positioned.firstWhere((p) => p.event.id == 'B');
      final eventC = positioned.firstWhere((p) => p.event.id == 'C');

      // GCal logic: A=0, B=1, C=0
      expect(eventA.column, 0);
      expect(eventB.column, 1);
      expect(eventC.column, 0);
    });

    test('Test 3: Midnight Crossing Split', () {
      final events = [
        const TimelineEvent(
          id: 'midnight_event',
          title: 'Late Night',
          startTime: '11:30 PM',
          endTime: '12:30 AM',
          type: TimelineEventType.standard,
        ),
      ];

      final positioned = TimelineLayoutEngine.calculatePositions(
        events: events,
        containerWidth: 1000,
      );

      // Should be split into 2 parts
      expect(positioned.length, 2);
      
      final part1 = positioned.firstWhere((p) => p.index == 0);
      final part2 = positioned.firstWhere((p) => p.index == 1);

      // Part 1: 11:30 PM to 12:00 AM (30 mins)
      // Height = (30/60 * 70) - 2.0 = 33.0
      expect(part1.height, closeTo(33.0, 0.1));
      // Part 2: 12:00 AM to 12:30 AM (30 mins)
      expect(part2.height, closeTo(33.0, 0.1));
    });

    test('Test 4: Snapping Grid Logic', () {
      // At 70px/hr, 15 min snap interval = 17.5px.
      // Midpoint = 8.75px.
      
      final top7 = TimelineLayoutEngine.snapTop(rawTop: 7.0, eventHeight: 60.0);
      final top10 = TimelineLayoutEngine.snapTop(rawTop: 10.0, eventHeight: 60.0);
      
      // 7px is < 8.75, so snaps to 0.
      expect(top7, 0.0);
      
      // 10px is > 8.75, so snaps to 17.5.
      expect(top10, 17.5);
    });
  });
}
