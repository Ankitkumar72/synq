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
      // First time user - seed sample tasks
      final sampleNotes = [
        Note(
          id: uuid.v4(),
          title: 'Strategy Planning',
          isTask: true,
          category: NoteCategory.work, // Added required field
          createdAt: DateTime.now(),
          scheduledTime: DateTime.now().add(const Duration(hours: 2)),
          endTime: DateTime.now().add(const Duration(hours: 3)),
        ),
        Note(
          id: uuid.v4(),
          title: 'Deep Work Block',
          isTask: false, // Assuming 'focus' meant a non-task note or different category, adapting to bool
          category: NoteCategory.work,
          createdAt: DateTime.now(),
          scheduledTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 2)),
        ),
      ];
      
      for (final note in sampleNotes) {
        await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notes')
          .doc(note.id)
          .set(note.toJson());
      }
    }
  }
}
