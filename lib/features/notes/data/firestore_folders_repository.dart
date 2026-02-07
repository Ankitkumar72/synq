import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/folder.dart';

class FirestoreFoldersRepository {
  final FirebaseFirestore firestore;
  final String userId;

  FirestoreFoldersRepository({required this.firestore, required this.userId});

  CollectionReference<Map<String, dynamic>> get _foldersCollection =>
      firestore.collection('users').doc(userId).collection('folders');

  Stream<List<Folder>> watchFolders() {
    return _foldersCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Folder.fromJson(doc.data());
      }).toList();
    });
  }

  Future<void> addFolder(Folder folder) async {
    await _foldersCollection.doc(folder.id).set(folder.toJson());
  }

  Future<void> updateFolder(Folder folder) async {
    await _foldersCollection.doc(folder.id).update(folder.toJson());
  }

  Future<void> deleteFolder(String folderId) async {
    await _foldersCollection.doc(folderId).delete();
  }
}
