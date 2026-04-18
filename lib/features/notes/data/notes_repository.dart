import '../domain/models/note.dart';

abstract class NotesRepository {
  Stream<List<Note>> watchNotes();
  Stream<List<Note>> watchFilteredNotes({
    bool? isCompleted,
    int? scheduledBeforeMs,
    int? scheduledAfterMs,
    String? folderId,
  });
  Stream<Note?> watchNote(String id);
  Future<void> addNote(Note note);
  Future<void> updateNote(Note note);
  Future<void> deleteNote(String id);
  Future<void> deleteNotes(List<String> ids);

  // Trash Management
  Stream<List<Note>> watchDeletedNotes();
  Future<void> restoreNote(String id);
  Future<void> permanentlyDeleteNote(String id);
  Future<void> permanentlyDeleteExpiredNotes();
}
