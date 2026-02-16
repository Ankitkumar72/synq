import '../domain/models/note.dart';

abstract class NotesRepository {
  Stream<List<Note>> watchNotes();
  Future<void> addNote(Note note);
  Future<void> updateNote(Note note);
  Future<void> deleteNote(String id);
  Future<void> deleteNotes(List<String> ids);
}
