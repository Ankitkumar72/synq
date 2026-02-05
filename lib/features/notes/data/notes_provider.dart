import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/note.dart';

/// Provider for managing notes and tasks
final notesProvider = NotifierProvider<NotesNotifier, List<Note>>(() {
  return NotesNotifier();
});

class NotesNotifier extends Notifier<List<Note>> {
  @override
  List<Note> build() {
    // Start with empty list - could load from storage in a real app
    return [];
  }

  /// Add a new note or task
  void addNote(Note note) {
    state = [...state, note];
  }

  /// Remove a note by ID
  void removeNote(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  /// Toggle task completion
  void toggleCompleted(String id) {
    state = state.map((n) {
      if (n.id == id) {
        return n.copyWith(isCompleted: !n.isCompleted);
      }
      return n;
    }).toList();
  }

  /// Update a note
  void updateNote(Note updatedNote) {
    state = state.map((n) {
      if (n.id == updatedNote.id) {
        return updatedNote;
      }
      return n;
    }).toList();
  }

  /// Get all tasks (notes with isTask = true)
  List<Note> get tasks => state.where((n) => n.isTask).toList();

  /// Get all notes (notes with isTask = false)
  List<Note> get notes => state.where((n) => !n.isTask).toList();

  /// Get notes by category
  List<Note> getByCategory(NoteCategory category) {
    return state.where((n) => n.category == category).toList();
  }
}
