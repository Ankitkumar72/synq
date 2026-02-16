import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/folder.dart';
import 'folders_repository.dart';

class FirestoreFoldersRepository implements FoldersRepository {
  final FirebaseFirestore firestore;
  final String userId;

  FirestoreFoldersRepository({required this.firestore, required this.userId});

  CollectionReference<Map<String, dynamic>> get _foldersCollection =>
      firestore.collection('users').doc(userId).collection('folders');

  @override
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

  @override
  Future<void> addFolder(Folder folder) async {
    await _foldersCollection.doc(folder.id).set(folder.toJson());
  }

  @override
  Future<void> updateFolder(Folder folder) async {
    await _foldersCollection.doc(folder.id).update(folder.toJson());
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    await _foldersCollection.doc(folderId).delete();
  }
}
