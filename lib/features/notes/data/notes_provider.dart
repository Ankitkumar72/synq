import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../domain/models/note.dart';
import 'firestore_notes_repository.dart';

final notesProvider = StreamNotifierProvider<NotesNotifier, List<Note>>(() {
  return NotesNotifier();
});

class NotesNotifier extends StreamNotifier<List<Note>> {
  late FirestoreNotesRepository _repository;

  @override
  Stream<List<Note>> build() {
    final authState = ref.watch(authProvider);
    final user = FirebaseAuth.instance.currentUser;

    if (!authState.isAuthenticated || user == null) {
      return Stream.value([]);
    }

    _repository = FirestoreNotesRepository(
      firestore: FirebaseFirestore.instance,
      userId: user.uid,
    );

    return _repository.watchNotes();
  }

  Future<void> addNote(Note note) async {
    await _repository.addNote(note);
  }

  Future<void> updateNote(Note note) async {
    await _repository.updateNote(note);
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
  }

  // Alias for deleteNote to match previous interface
  Future<void> removeNote(String id) async {
    await deleteNote(id);
  }

  // Toggle completed status for a note
  Future<void> toggleCompleted(String id) async {
    final currentNotes = state.value ?? [];
    final note = currentNotes.firstWhere((n) => n.id == id, orElse: () => throw Exception('Note not found'));
    final updatedNote = note.copyWith(isCompleted: !note.isCompleted);
    await _repository.updateNote(updatedNote);
  }
}
