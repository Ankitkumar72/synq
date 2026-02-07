import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/note.dart';

class FirestoreNotesRepository {
  final FirebaseFirestore _firestore;
  final String userId;
  
  FirestoreNotesRepository({
    required FirebaseFirestore firestore,
    required this.userId,
  }) : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _notesCollection => 
    _firestore.collection('users').doc(userId).collection('notes');
  
  // Real-time stream (works offline too!)
  Stream<List<Note>> watchNotes() {
    return _notesCollection
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Note.fromJson(doc.data()))
          .toList());
  }
  
  // CRUD operations work offline - auto-sync when online
  Future<void> addNote(Note note) async {
    await _notesCollection.doc(note.id).set(note.toJson());
  }
  
  Future<void> updateNote(Note note) async {
    await _notesCollection.doc(note.id).update(note.toJson());
  }
  
  Future<void> deleteNote(String id) async {
    await _notesCollection.doc(id).delete();
  }

  Future<void> deleteNotes(List<String> ids) async {
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.delete(_notesCollection.doc(id));
    }
    await batch.commit();
  }
}
