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
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Note.fromJson(doc.data()))
          .toList());
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
