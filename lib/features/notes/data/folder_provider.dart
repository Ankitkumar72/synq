import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/folder.dart';
import 'folders_repository.dart';
import 'repository_provider.dart';

final foldersProvider = StreamNotifierProvider<FoldersNotifier, List<Folder>>(() {
  return FoldersNotifier();
});

class FoldersNotifier extends StreamNotifier<List<Folder>> {
  late FoldersRepository _repository;

  @override
  Stream<List<Folder>> build() {
    ref.watch(syncCoordinatorProvider);
    _repository = ref.watch(foldersRepositoryProvider);
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
