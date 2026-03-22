import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/note.dart';
import 'notes_repository.dart';

class FirestoreNotesRepository implements NotesRepository {
  final FirebaseFirestore _firestore;
  final String userId;

  FirestoreNotesRepository({
    required FirebaseFirestore firestore,
    required this.userId,
  }) : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _notesCollection =>
      _firestore.collection('users').doc(userId).collection('notes');

  // Real-time stream (works offline too!)
  @override
  Stream<List<Note>> watchNotes() {
    return _notesCollection
        .where('is_deleted', isEqualTo: false)
        .orderBy('created_at_ms', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Note.fromJson(doc.data())).toList();
    });
  }

  @override
  Stream<List<Note>> watchFilteredNotes({
    bool? isCompleted,
    bool? isTask,
    int? scheduledBeforeMs,
    int? scheduledAfterMs,
    String? folderId,
  }) {
    return watchNotes().map((notes) {
      return notes.where((note) {
        if (isCompleted != null && note.isCompleted != isCompleted) return false;
        if (isTask != null && note.isTask != isTask) return false;
        if (folderId != null && note.folderId != folderId) return false;
        
        final schedMs = note.scheduledTime?.millisecondsSinceEpoch;
        if (scheduledBeforeMs != null && (schedMs == null || schedMs >= scheduledBeforeMs)) return false;
        if (scheduledAfterMs != null && (schedMs == null || schedMs < scheduledAfterMs)) return false;
        
        return true;
      }).toList();
    });
  }

  @override
  Stream<Note?> watchNote(String id) {
    return _notesCollection.doc(id).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return Note.fromJson(snapshot.data()!);
      }
      return null;
    });
  }

  // CRUD operations work offline - auto-sync when online
  @override
  Future<void> addNote(Note note) async {
    await _notesCollection.doc(note.id).set(note.toJson());
  }

  @override
  Future<void> updateNote(Note note) async {
    await _notesCollection.doc(note.id).update(note.toJson());
  }

  @override
  Future<void> deleteNote(String id) async {
    await _notesCollection.doc(id).delete();
  }

  @override
  Future<void> deleteNotes(List<String> ids) async {
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.delete(_notesCollection.doc(id));
    }
    await batch.commit();
  }
}
