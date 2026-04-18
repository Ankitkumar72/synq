import '../domain/models/note.dart';
import '../../../../core/database/local_database.dart';
import 'notes_repository.dart';

class LocalDbNotesRepository implements NotesRepository {
  LocalDbNotesRepository(this._localDb);

  final LocalDatabase _localDb;

  @override
  Stream<List<Note>> watchNotes() => _localDb.watchFilteredNotes(isTask: false);

  @override
  Stream<List<Note>> watchFilteredNotes({
    bool? isCompleted,
    int? scheduledBeforeMs,
    int? scheduledAfterMs,
    String? folderId,
  }) {
    return _localDb.watchFilteredNotes(
      isCompleted: isCompleted,
      isTask: false,
      scheduledBeforeMs: scheduledBeforeMs,
      scheduledAfterMs: scheduledAfterMs,
      folderId: folderId,
    );
  }

  @override
  Stream<Note?> watchNote(String id) {
    return _localDb.watchNote(id).map((n) => n != null && !n.isTask ? n : null);
  }

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

  @override
  Stream<List<Note>> watchDeletedNotes() => _localDb.watchDeletedNotes();

  @override
  Future<void> restoreNote(String id) => _localDb.restoreNote(id);

  @override
  Future<void> permanentlyDeleteNote(String id) => _localDb.hardDeleteNote(id);

  @override
  Future<void> permanentlyDeleteExpiredNotes() => _localDb.permanentlyDeleteExpiredNotes();
}
