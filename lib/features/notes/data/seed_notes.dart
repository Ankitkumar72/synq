import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../domain/models/note.dart';

const uuid = Uuid();

class SeedNotesService {
  static Future<void> seedIfEmpty(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notes')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      final sampleNotes = [
        Note(
          id: uuid.v4(),
          title: '🎯 What is "Strategy Planning"?',
          body:
              'Welcome! This is a **Task**. \n\nTasks are designed for action. Unlike regular notes, they help you track progress on your big goals. \n\n**Try this:** \n1. Tap the checkbox to complete a step. \n2. Use this space to break down your roadmap or development plan. \n3. Stay focused on your Deep Work blocks!',
          isTask: true,
          category: NoteCategory.work,
          createdAt: DateTime.now(),
        ),
        Note(
          id: uuid.v4(),
          title: '💡 Pro Tip: Deep Work',
          body:
              'This is a **Note**. \n\nNotes are perfect for capturing ideas, snippets of code, or brainstorming sessions that don\'t need a "Done" button. Use them for your research and reference material.',
          isTask: false,
          category: NoteCategory.idea,
          createdAt: DateTime.now(),
        ),
      ];

      for (final note in sampleNotes) {
        final noteData = note.toJson();
        noteData['server_updated_at'] = DateTime.now().toIso8601String();
        noteData['is_deleted'] = false;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notes')
            .doc(note.id)
            .set(noteData);
      }
    }
  }
}
