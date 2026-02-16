import '../domain/models/note.dart';
import 'local_database.dart';
import 'notes_repository.dart';

class LocalDbNotesRepository implements NotesRepository {
  LocalDbNotesRepository(this._database);

  final LocalDatabase _database;

  @override
  Stream<List<Note>> watchNotes() {
    return _database.watchNotes();
  }

  @override
  Future<void> addNote(Note note) async {
    final stamped = note.copyWith(updatedAt: DateTime.now());
    await _database.upsertNote(
      stamped,
      source: SyncWriteSource.local,
    );
  }

  @override
  Future<void> updateNote(Note note) async {
    final stamped = note.copyWith(updatedAt: DateTime.now());
    await _database.upsertNote(
      stamped,
      source: SyncWriteSource.local,
    );
  }

  @override
  Future<void> deleteNote(String id) async {
    await _database.markNoteDeleted(
      id,
      source: SyncWriteSource.local,
    );
  }

  @override
  Future<void> deleteNotes(List<String> ids) async {
    await _database.markNotesDeleted(
      ids,
      source: SyncWriteSource.local,
    );
  }
}
