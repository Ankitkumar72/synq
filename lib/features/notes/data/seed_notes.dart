import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../domain/models/note.dart';
import '../../../../core/database/local_database.dart';

class SeedNotesService {
  static const _uuid = Uuid();

  static Future<void> seedIfEmpty(LocalDatabase database) async {
    try {
      final existingNotes = await database.getNotes();

      if (existingNotes.isNotEmpty) {
        debugPrint('SEED: Skipped — ${existingNotes.length} notes already exist');
        return;
      }

      debugPrint('SEED: Database is empty, inserting sample notes...');
      final now = DateTime.now();
        
      final sampleNotes = [
        Note(
          id: _uuid.v4(),
          title: '🎯 What is "Strategy Planning"?',
          body:
              'Welcome! This is a **Task**. \n\nTasks are designed for action. Unlike regular notes, they help you track progress on your big goals. \n\n**Try this:** \n1. Tap the checkbox to complete a step. \n2. Use this space to break down your roadmap or development plan. \n3. Stay focused on your Deep Work blocks!',
          isTask: true,
          category: NoteCategory.work,
          createdAt: now,
        ),
        Note(
          id: _uuid.v4(),
          title: '💡 Pro Tip: Deep Work',
          body:
              'This is a **Note**. \n\nNotes are perfect for capturing ideas, snippets of code, or brainstorming sessions that don\'t need a "Done" button. Use them for your research and reference material.',
          isTask: false,
          category: NoteCategory.idea,
          createdAt: now.subtract(const Duration(seconds: 1)),
        ),
      ];

      for (final note in sampleNotes) {
        await database.upsertNote(note, source: SyncWriteSource.local);
        debugPrint('SEED: Inserted "${note.title}" (isTask=${note.isTask})');
      }
      debugPrint('SEED: Completed — ${sampleNotes.length} notes seeded');
    } catch (e) {
      debugPrint('SEED_FAILED: $e');
    }
  }
}
