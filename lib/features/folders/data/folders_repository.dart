import '../domain/models/folder.dart';

abstract class FoldersRepository {
  Stream<List<Folder>> watchFolders();
  Future<void> addFolder(Folder folder);
  Future<void> updateFolder(Folder folder);
  Future<void> deleteFolder(String folderId);
}
