import '../domain/models/note.dart';
import 'local_database.dart';
import 'notes_repository.dart';

class LocalDbNotesRepository implements NotesRepository {
  LocalDbNotesRepository(this._localDb);

  final LocalDatabase _localDb;

  @override
  Stream<List<Note>> watchNotes() => _localDb.watchNotes();

  @override
  Stream<List<Note>> watchFilteredNotes({
    bool? isCompleted,
    bool? isTask,
    int? scheduledBeforeMs,
    int? scheduledAfterMs,
    String? folderId,
  }) {
    return _localDb.watchFilteredNotes(
      isCompleted: isCompleted,
      isTask: isTask,
      scheduledBeforeMs: scheduledBeforeMs,
      scheduledAfterMs: scheduledAfterMs,
      folderId: folderId,
    );
  }

  @override
  Stream<Note?> watchNote(String id) => _localDb.watchNote(id);

  @override
  Future<void> addNote(Note note) async {
    final stamped = note.copyWith(updatedAt: DateTime.now());
    await _localDb.upsertNote(stamped, source: SyncWriteSource.local);
  }

  @override
  Future<void> updateNote(Note note) async {
    final stamped = note.copyWith(updatedAt: DateTime.now());
    await _localDb.upsertNote(stamped, source: SyncWriteSource.local);
  }

  @override
  Future<void> deleteNote(String id) async {
    await _localDb.markNoteDeleted(id, source: SyncWriteSource.local);
  }

  @override
  Future<void> deleteNotes(List<String> ids) async {
    await _localDb.markNotesDeleted(ids, source: SyncWriteSource.local);
  }
}
