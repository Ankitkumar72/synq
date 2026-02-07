import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../domain/models/folder.dart';
import 'firestore_folders_repository.dart';

final foldersProvider = StreamNotifierProvider<FoldersNotifier, List<Folder>>(() {
  return FoldersNotifier();
});

class FoldersNotifier extends StreamNotifier<List<Folder>> {
  late FirestoreFoldersRepository _repository;

  @override
  Stream<List<Folder>> build() {
    final authState = ref.watch(authProvider);
    final user = FirebaseAuth.instance.currentUser;

    if (!authState.isAuthenticated || user == null) {
      return Stream.value([]);
    }

    _repository = FirestoreFoldersRepository(
      firestore: FirebaseFirestore.instance,
      userId: user.uid,
    );

    return _repository.watchFolders();
  }

  Future<void> addFolder(Folder folder) async {
    await _repository.addFolder(folder);
  }

  Future<void> updateFolder(Folder folder) async {
    await _repository.updateFolder(folder);
  }

  Future<void> deleteFolder(String id) async {
    await _repository.deleteFolder(id);
  }

  Future<void> toggleFavorite(String id) async {
    final currentFolders = state.value ?? [];
    final folder = currentFolders.firstWhere((f) => f.id == id, orElse: () => throw Exception('Folder not found'));
    final updatedFolder = folder.copyWith(isFavorite: !folder.isFavorite);
    await updateFolder(updatedFolder);
  }
}
