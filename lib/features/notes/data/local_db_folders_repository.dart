import '../domain/models/folder.dart';
import 'folders_repository.dart';
import 'local_database.dart';

class LocalDbFoldersRepository implements FoldersRepository {
  LocalDbFoldersRepository(this._database);

  final LocalDatabase _database;

  @override
  Stream<List<Folder>> watchFolders() {
    return _database.watchFolders();
  }

  @override
  Future<void> addFolder(Folder folder) async {
    await _database.upsertFolder(
      folder,
      source: SyncWriteSource.local,
    );
  }

  @override
  Future<void> updateFolder(Folder folder) async {
    await _database.upsertFolder(
      folder,
      source: SyncWriteSource.local,
    );
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    await _database.markFolderDeleted(
      folderId,
      source: SyncWriteSource.local,
    );
  }
}
