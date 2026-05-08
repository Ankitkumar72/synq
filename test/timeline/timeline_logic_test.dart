import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synq/features/timeline/data/timeline_provider.dart';
import 'package:synq/features/notes/domain/models/note.dart';
import 'package:synq/features/notes/data/notes_provider.dart';
import 'package:synq/features/tasks/data/tasks_provider.dart';
import 'package:synq/features/timeline/domain/models/timeline_event.dart';
import 'package:intl/intl.dart';

class MockNotesNotifier extends NotesNotifier {
  final List<Note> _notes;
  MockNotesNotifier(this._notes);
  
  @override
  Stream<List<Note>> build() => Stream.value(_notes);
}

void main() {
  group('TimelineEventsNotifier Timezone Logic', () {
    testWidgets('Should localize UTC notes to local time strings', (tester) async {
      final utcTime = DateTime.utc(2026, 5, 8, 10, 0);
      final note = Note(
        id: '1',
        title: 'UTC Event',
        category: NoteCategory.work,
        createdAt: DateTime.now(),
        scheduledTime: utcTime,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesProvider.overrideWith(() => MockNotesNotifier([note])),
            selectedDateProvider.overrideWith((ref) => DateTime(2026, 5, 8)),
            timelineTasksProvider.overrideWith((ref, date) => Stream.value([])),
            minuteProvider.overrideWith((ref) => Stream.value(0)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final events = ref.watch(timelineEventsProvider);
                  if (events.isEmpty) return const SizedBox.shrink();
                  return Text(events.first.startTime, key: const Key('start_time'));
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final expectedLocalTime = utcTime.toLocal();
      final expectedString = DateFormat('h:mm a').format(expectedLocalTime);

      expect(find.byKey(const Key('start_time')), findsOneWidget);
      expect(find.text(expectedString), findsOneWidget);
    });

    testWidgets('Should filter out notes outside the local day boundary', (tester) async {
      final outOfBoundsUtc = DateTime.utc(2026, 5, 8, 23, 0); 
      
      final note = Note(
        id: '2',
        title: 'Out of Bounds Event',
        category: NoteCategory.work,
        createdAt: DateTime.now(),
        scheduledTime: outOfBoundsUtc,
      );

      int count = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesProvider.overrideWith(() => MockNotesNotifier([note])),
            selectedDateProvider.overrideWith((ref) => DateTime(2026, 5, 8)),
            timelineTasksProvider.overrideWith((ref, date) => Stream.value([])),
            minuteProvider.overrideWith((ref) => Stream.value(0)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final events = ref.watch(timelineEventsProvider);
                  count = events.length;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final localScheduled = outOfBoundsUtc.toLocal();
      final isSameDay = localScheduled.year == 2026 && 
                        localScheduled.month == 5 && 
                        localScheduled.day == 8;
      
      if (isSameDay) {
        expect(count, 1);
      } else {
        expect(count, 0);
      }
    });

    testWidgets('Should sort events by local time', (tester) async {
      final utc10 = DateTime.utc(2026, 5, 8, 10, 0);
      final utc09 = DateTime.utc(2026, 5, 8, 9, 0);
      
      final notes = [
        Note(id: '1', title: 'Late', category: NoteCategory.work, createdAt: DateTime.now(), scheduledTime: utc10),
        Note(id: '2', title: 'Early', category: NoteCategory.work, createdAt: DateTime.now(), scheduledTime: utc09),
      ];

      List<TimelineEvent> eventsResult = [];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesProvider.overrideWith(() => MockNotesNotifier(notes)),
            selectedDateProvider.overrideWith((ref) => DateTime(2026, 5, 8)),
            timelineTasksProvider.overrideWith((ref, date) => Stream.value([])),
            minuteProvider.overrideWith((ref) => Stream.value(0)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  eventsResult = ref.watch(timelineEventsProvider);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(eventsResult.length, 2);
      expect(eventsResult[0].title, 'Early');
      expect(eventsResult[1].title, 'Late');
    });
  });
}
