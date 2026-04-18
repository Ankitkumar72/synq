import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/note.dart';
import 'notes_repository.dart';
import '../../../core/providers/repository_provider.dart';
import '../../attachments/data/image_storage_service.dart';

final trashProvider = StreamNotifierProvider<TrashNotifier, List<Note>>(() {
  return TrashNotifier();
});

class TrashNotifier extends StreamNotifier<List<Note>> {
  late NotesRepository _repository;

  @override
  Stream<List<Note>> build() {
    _repository = ref.watch(notesRepositoryProvider);
    return _repository.watchDeletedNotes();
  }

  Future<void> restoreNote(String id) async {
    await _repository.restoreNote(id);
  }

  Future<void> permanentlyDeleteNote(Note note) async {
    // 1. Delete attachments
    if (note.attachments.isNotEmpty) {
      try {
        await ImageStorageService.deleteFiles(note.attachments);
      } catch (e) {
        // Log error but continue with DB deletion
      }
    }

    // 2. Delete from DB
    await _repository.permanentlyDeleteNote(note.id);
  }

  Future<void> emptyTrash() async {
    final deletedNotes = state.value ?? [];
    for (final note in deletedNotes) {
      await permanentlyDeleteNote(note);
    }
  }

  Future<void> cleanExpiredNotes() async {
    // This is the automatic cleanup
    await _repository.permanentlyDeleteExpiredNotes();
  }
}
